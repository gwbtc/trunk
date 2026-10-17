// The guest page's script (wire 16 to 19): a call for someone with no
// ship, through an invite or a link the host or one of its apps made.
//
// It runs in one of two places, from the same three files:
//   on the ship, at /apps/trunk/guest/<code>, where it asks the ship for
//   a ticket;
//   on the call server, at /join/#<ship's host>/<code> (wire 19). There
//   Galène's CSP lets the page connect only to its own origin, so it
//   cannot reach the ship. It sends the guest to the ship's page with
//   #hop, which gets a ticket and sends them back with it in the
//   fragment. The call then runs on the call server's own origin, so
//   Galène needs no allowOrigin for the ship. The guest's secret never
//   leaves the ship's origin.
//
// The ship mints the ticket and Galène's own protocol.js does the rest,
// so the wire protocol cannot drift from it. The Join button is the
// user gesture that unlocks audio and asks for the microphone.
//
// It publishes the way Talon does, so Talon can show it: one stream,
// labelled 'camera', with the microphone and one video sender. The
// camera and a shared screen take turns on that sender (replaceTrack,
// no renegotiation), and there is no simulcast. A 'talon-video' message
// says whether video is on and 'talon-mute' whether the mic is off.
// Galène does not replay them to newcomers, so both go again whenever
// someone joins.
(function () {
  var $ = function (id) { return document.getElementById(id); };
  var path = '/apps/trunk/guest/';
  var onShip = location.pathname.indexOf(path) === 0;
  var hash = location.hash.slice(1).split('/');
  var host = onShip ? location.host : hash[0];
  var code = onShip ? location.pathname.slice(path.length).split('/')[0] : hash[1];
  var base = path + code;
  // What the page keeps is per link. On a call server every ship's
  // guests share one origin, so there it is per ship too.
  var key = onShip ? code : host + '/' + code;
  var given = null;    // on a call server: the room and ticket the ship sent
  var got = 0;         // when they came
  var conn = null, up = null, vsend = null, mic = null, cam = null, screen = null, preview = null;
  var muted = false, speak = false;
  var videoOn = {};   // by connection id, from talon-video
  var micOff = {};    // by connection id, from talon-mute
  var streams = {};   // by connection id: the stream that user publishes
  var voices = {};    // by connection id: the receiver of their audio
  var speakTimer = null;
  var gen = 0;         // bumped by a full stop, so late work can tell the call ended
  var tries = 0;       // rejoins since the last good join
  var rejoin = null;   // the timer of a rejoin to come
  var wake = null;     // the screen wake lock, on a phone
  var tabs = window.BroadcastChannel ? new BroadcastChannel('trunk-guest-' + key) : null;

  // Kept per invite or link, so a reload or a rejoin is the same guest.
  function recall(k) { try { return localStorage.getItem(key + ':' + k); } catch (e) { return null; } }
  function keep(k, v) { try { localStorage.setItem(key + ':' + k, v); } catch (e) {} }

  // an error of our own reads as it is; anything else (a ship that is
  // down, an HTML error page) reads as one plain sentence
  function fail(e) {
    say(e && e.name === 'Error' ? e.message : 'Could not reach the host. Try again in a minute.', true);
  }

  function say(text, bad) {
    $('status').textContent = text;
    $('status').className = bad ? 'status bad' : 'status';
  }

  // Galène names each person by the username in their ticket: an @p for
  // a ship, a guest id for a guest. A readable name rides in the
  // per-user data. A guest is always marked, so nobody passes as a ship.
  function nameOf(u) {
    var user = (u && u.username) || '';
    var typed = u && u.data && u.data.name;
    if (user.indexOf('guest-') === 0) return (typed || user) + ' (guest)';
    // a ship's username is signed; a name it typed shows beside it
    return typed && typed !== user ? typed + ' (' + user + ')' : (user || typed || 'someone');
  }

  function tile(id) {
    var t = document.getElementById('t-' + id);
    if (t) return t;
    t = document.createElement('div');
    t.className = 'tile';
    t.id = 't-' + id;
    var v = document.createElement('video');
    v.autoplay = true;
    v.playsInline = true;
    var face = document.createElement('div');
    face.className = 'face';
    var name = document.createElement('div');
    name.className = 'name';
    t.append(v, face, name);
    t.tabIndex = 0;
    t.title = 'Enlarge';
    t.setAttribute('role', 'button');
    t.setAttribute('aria-pressed', 'false');
    t.onclick = function () { t.setAttribute('aria-pressed', t.classList.toggle('big')); };
    t.onkeydown = function (e) {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); t.onclick(); }
    };
    t.ondblclick = function () { if (t.requestFullscreen) t.requestFullscreen().catch(function () {}); };
    // A shared screen is wider than any camera here (1280), so give it
    // the room, unless someone is already enlarged.
    v.addEventListener('resize', function () {
      if (conn && id !== conn.id && v.videoWidth > 1280 && !document.querySelector('.tile.big')) {
        t.classList.add('big');
        t.setAttribute('aria-pressed', 'true');
      }
    });
    $('grid').append(t);
    return t;
  }

  // One tile per person on the call, ourselves first. Listeners from a
  // listen link have no voice or video, so they are only counted.
  function render() {
    // after stop(), an old socket's close still closes its streams
    if (!conn) return;
    var users = conn.users || {};
    var all = Object.keys(users);
    var ids = all.filter(function (id) { return users[id].username !== 'listener'; });
    var listening = all.length - ids.length;
    var others = ids.length - 1;
    $('alone').hidden = others > 0 && !listening;
    $('alone').textContent = (others > 0 ? '' : 'Nobody else is here yet. Stay on this page and others will appear. ')
      + (listening ? listening + (listening === 1 ? ' person is' : ' people are') + ' listening.' : '');
    if (conn && conn.id && ids.indexOf(conn.id) > 0) {
      ids.splice(ids.indexOf(conn.id), 1);
      ids.unshift(conn.id);
    }
    [].slice.call($('grid').children).forEach(function (t) {
      if (ids.indexOf(t.id.slice(2)) < 0) t.remove();
    });
    ids.forEach(function (id) {
      var t = tile(id);
      var me = id === conn.id;
      var label = me ? ((users[id].data && users[id].data.name) || 'You') + ' (you)' : nameOf(users[id]);
      if ((me && muted) || (!me && micOff[id])) label += ' · muted';
      t.querySelector('.name').textContent = label;
      t.querySelector('.face').textContent = nameOf(users[id]);
      var v = t.querySelector('video');
      var src = (me ? preview : streams[id]) || null;
      if (me) v.muted = true;
      if (v.srcObject !== src) {
        v.srcObject = src;
        // Safari plays sound only after a tap when no mic is in use
        if (src) v.play().catch(function (e) { if (e && e.name === 'NotAllowedError') $('sound').hidden = false; });
      }
      var on = me ? !!(screen || cam) : !!videoOn[id];
      t.classList.toggle('video', on);
    });
  }

  // Who is talking. Galène does not negotiate the RTP audio-level
  // extension, so getSynchronizationSources has no level. The receiver's
  // stats carry one taken from the decoded audio.
  function startSpeaking() {
    if (speakTimer) return;
    speakTimer = setInterval(function () {
      var mine = conn && document.getElementById('t-' + conn.id);
      // muted, nobody hears us, so no ring
      if (mine && muted) mine.classList.remove('speaking');
      else if (mine && up) up.pc.getStats().then(function (st) {
        var loud = false;
        st.forEach(function (r) { if (r.type === 'media-source' && r.kind === 'audio' && r.audioLevel > 0.02) loud = true; });
        mine.classList.toggle('speaking', loud && !muted);
      }).catch(function () {});
      Object.keys(voices).forEach(function (id) {
        voices[id].getStats().then(function (st) {
          var loud = false;
          st.forEach(function (r) {
            if (r.type === 'inbound-rtp' && r.kind === 'audio' && r.audioLevel > 0.02) loud = true;
          });
          var t = document.getElementById('t-' + id);
          if (t) t.classList.toggle('speaking', loud);
        }).catch(function () {});
      });
    }, 300);
  }

  // Galène's protocol.js. On the ship, the copy pinned in the desk: one
  // from the call server would run on this ship's origin. On the call
  // server, its own.
  function loadProtocol() {
    if (window.ServerConnection) return Promise.resolve();
    return new Promise(function (ok, fail) {
      var s = document.createElement('script');
      s.src = onShip ? '/apps/trunk/protocol.js' : '/protocol.js';
      s.onload = ok;
      s.onerror = function () {
        fail(new Error('Could not reach the ' + (onShip ? 'host' : 'call server') + '. Try again in a minute.'));
      };
      document.head.append(s);
    });
  }

  function stopTracks(s) { if (s) s.getTracks().forEach(function (t) { t.stop(); }); }

  // `keep`: a rejoin is coming, so keep the mic, camera, share and mute
  function stop(keep) {
    if (conn) {
      // a late error or message from the old socket must not touch the page
      conn.onclose = conn.onerror = conn.onjoined = conn.onuser = conn.onusermessage = conn.ondownstream = null;
      try { conn.close(); } catch (e) {}
      conn = null;
    }
    up = vsend = null;
    streams = {}; videoOn = {}; micOff = {}; voices = {};
    if (speakTimer) { clearInterval(speakTimer); speakTimer = null; }
    if (wake) { wake.release().catch(function () {}); wake = null; }
    $('grid').replaceChildren();
    if (keep) return;
    gen++;
    clearTimeout(rejoin);
    rejoin = null;
    // a Join after this goes back to the ship for a new ticket
    given = null;
    stopTracks(mic); stopTracks(cam); stopTracks(screen);
    mic = cam = screen = preview = null;
    muted = false;
    $('mute').textContent = 'Mute';
    $('camera').textContent = 'Start camera';
    $('share').textContent = 'Share screen';
    ['mute', 'camera', 'share'].forEach(function (b) { $(b).classList.remove('on'); });
    $('alone').hidden = true;
    $('sound').hidden = true;
    document.body.classList.remove('in');
    $('controls').hidden = true;
    $('form').hidden = false;
    $('join').disabled = false;
    $('join').textContent = 'Join again';
  }

  // What others need to draw our tile: to everyone (dest ''), or only to
  // someone who just joined, since Galène does not replay these.
  function announce(dest) {
    if (!conn || !up) return;
    conn.userMessage('talon-video', dest || '', !!(screen || cam));
    conn.userMessage('talon-mute', dest || '', muted);
  }

  async function showVideo() {
    var t = screen || cam;
    preview = t ? new MediaStream(t.getVideoTracks()) : null;
    if (vsend) await vsend.replaceTrack(t ? t.getVideoTracks()[0] : null);
    $('camera').classList.toggle('on', !!cam);
    $('camera').textContent = cam ? 'Stop camera' : 'Start camera';
    $('share').classList.toggle('on', !!screen);
    $('share').textContent = screen ? 'Stop sharing' : 'Share screen';
    announce();
    render();
  }

  // The microphone and one video sender with no track yet. The camera
  // or a shared screen later goes on that sender.
  function publish() {
    up = conn.newUpStream();
    up.label = 'camera';
    var s = mic || new MediaStream();
    up.setStream(s);
    if (mic) mic.getAudioTracks().forEach(function (t) {
      up.pc.addTransceiver(t, { direction: 'sendonly', streams: [s] });
    });
    vsend = up.pc.addTransceiver('video', { direction: 'sendonly', streams: [s] }).sender;
    up.onstatus = function (st) {
      if (st === 'failed') say('Others cannot hear you right now. Leave and join again.', true);
    };
  }

  function keepAwake() {
    if (navigator.wakeLock && document.visibilityState === 'visible' && conn && !wake) {
      navigator.wakeLock.request('screen').then(function (w) { wake = w; w.onrelease = function () { wake = null; }; }).catch(function () {});
    }
  }
  document.addEventListener('visibilitychange', keepAwake);

  // To the ship's own page, which sends the guest back with a ticket.
  // The mark says this tab asked, so a ticket in a link someone made up
  // is never shown. A page that cannot keep it would hop forever.
  // `again`: the guest pressed Join, so tell them to press it once more.
  function hop(again) {
    try {
      sessionStorage.setItem(key + ':hop', '1');
      if (again) sessionStorage.setItem(key + ':again', '1');
      else sessionStorage.removeItem(key + ':again');
    } catch (e) {
      say('This browser blocks the storage this page needs. Allow it for this site, then open the link again.', true);
      return;
    }
    say('Taking you to the host…');
    location.replace(location.protocol + '//' + host + base + '#hop');
  }

  // whether this tab set a mark (hop or again) before it went, once
  function marked(k) {
    try {
      var m = sessionStorage.getItem(key + ':' + k);
      sessionStorage.removeItem(key + ':' + k);
      return !!m;
    } catch (e) {
      return false;
    }
  }

  // A guest's ticket. On the ship, from its POST route, and the page
  // keeps the secret that names the guest. On a call server, the one the
  // ship sent back while it has a minute left, or else a trip for a new
  // one (null). A ticket lasts an hour from when the ship made it, just
  // before it came here. This clock may differ from the ship's, so it
  // counts from when it came, not from its expiry.
  async function ticket() {
    if (!onShip) {
      var g = given && given.ticket;
      if (g && Date.now() - got < 59 * 60000) return g;
      hop(true);
      return null;
    }
    var r = await fetch(base, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ secret: recall('secret') }),
    });
    var t = await r.json();
    if (!r.ok) throw new Error(t.error || 'The host refused.');
    keep('secret', t.secret);
    return t;
  }

  // On the ship, asked by a call server's page (#hop): get the room and
  // a ticket, and go back with them. They go only to the origin of the
  // ticket's own location, which is the call server this ship chose,
  // never to one a link names. The secret stays here.
  async function back() {
    say('Taking you to the call…');
    try {
      var r = await fetch(base + '/room', { cache: 'no-store' });
      var room = await r.json();
      if (!r.ok) throw new Error(room.error || 'This link has ended. Ask the host for a new one.');
      var t = await ticket();
      delete t.secret;
      location.replace(new URL(t.location).origin + '/join/#' + host + '/' + code + '/'
        + encodeURIComponent(JSON.stringify({ host: room.host, title: room.title, speak: room.speak, ticket: t })));
    } catch (e) {
      fail(e);
    }
  }

  async function join(ev) {
    if (ev) { ev.preventDefault(); tries = 0; }
    // a full stop while this waits makes it stale: it lets go of what it
    // got and leaves the status alone
    var run = gen;
    var name = $('name').value.trim();
    if (!name) return;
    keep('name', name);
    $('join').disabled = true;
    say(tries ? 'Connection lost. Rejoining…' : 'Joining…');
    try {
      // the ticket first, so a link that has ended never asks for the mic
      var t = await ticket();
      if (run !== gen || !t) return;
      // on a call server, only its own websocket
      var endpoint = onShip ? t.endpoint
        : (location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/ws';
      if (location.protocol === 'https:' && endpoint.indexOf('ws:') === 0) {
        throw new Error('The host\'s call server does not take secure connections yet.');
      }
      // an address that is not secure has no microphone to ask for
      if (t.speak && !mic && window.isSecureContext) {
        say('Allow the microphone when your browser asks.');
        var m = null;
        try { m = await navigator.mediaDevices.getUserMedia({ audio: true, video: false }); } catch (e) {}
        if (run !== gen) { stopTracks(m); return; }
        mic = m;
        if (!mic) say('No microphone, so others will not hear you.');
      }
      var group = t.location.split('/group/')[1].replace(/\/$/, '');
      await loadProtocol();
      if (run !== gen) return;
      var joined = false;  // on the call, on this connection
      var why = null;      // what went wrong before the join, if protocol.js said
      conn = new ServerConnection();
      conn.onconnected = function () {
        this.join(group, t.username, { type: 'token', token: t.token }, { name: name });
      };
      conn.onjoined = function (kind, g, perms, status, data, error, message) {
        if (kind === 'fail' || kind === 'redirect') {
          say(message || error || 'The call server refused.', true);
          stop();
          return;
        }
        if (kind !== 'join') return;
        joined = true;
        this.request({ '': ['audio', 'video'] });
        var can = perms.indexOf('present') >= 0;
        if (can) publish();
        if (can && (cam || screen)) showVideo();
        if (mic) mic.getAudioTracks().forEach(function (tr) { tr.enabled = !muted; });
        tries = 0;
        if (tabs) tabs.postMessage('joined');
        keepAwake();
        document.body.classList.add('in');
        $('form').hidden = true;
        $('controls').hidden = false;
        $('mute').hidden = !mic;
        $('camera').hidden = !can;
        $('share').hidden = !can || !(navigator.mediaDevices && navigator.mediaDevices.getDisplayMedia);
        say(!can ? 'You are watching and listening.'
          : mic ? 'You are on the call.'
          : !window.isSecureContext ? 'You are on the call. This address is not secure, so others cannot hear you.'
          : 'Others cannot hear you. Allow the microphone in your browser, then leave and join again.', can && !mic);
        announce();
        startSpeaking();
        render();
      };
      conn.onuser = function (id, kind) {
        if (kind === 'delete') { delete streams[id]; delete videoOn[id]; delete micOff[id]; delete voices[id]; }
        if (kind === 'add' && id !== conn.id) announce(id);
        render();
      };
      conn.onusermessage = function (source, dest, username, time, privileged, kind, error, value) {
        // an op removed us; the server closes the socket next
        if (kind === 'kicked' && privileged) {
          stop();
          say((typeof value === 'string' && value) || 'The host removed you from the call.', true);
          return;
        }
        if (kind === 'talon-video') videoOn[source] = !!value;
        else if (kind === 'talon-mute') micOff[source] = !!value;
        else return;
        render();
      };
      conn.ondownstream = function (s) {
        s.ondowntrack = function (track, tr, stream) {
          streams[s.source] = s.stream || stream;
          if (track.kind === 'audio') voices[s.source] = tr.receiver;
          render();
        };
        s.onclose = function () {
          if (streams[s.source] === s.stream) delete streams[s.source];
          render();
        };
      };
      // a drop the guest did not ask for: rejoin, keeping the mic and
      // camera, a few times before giving up. A first join that never
      // got on would only fail again.
      conn.onclose = function () {
        if (!joined && !tries) {
          // from the ship's page, most often the call server does not
          // allow the ship's origin, which no retry fixes
          say(why || 'Could not reach the call server. ' + (onShip ? 'Tell the host.' : 'Try again in a minute.'), true);
          stop();
          return;
        }
        if (tries < 3) {
          tries++;
          stop(true);
          rejoin = setTimeout(join, 1500 * tries);
          return;
        }
        say('You were disconnected. Press Join again to come back.');
        stop();
      };
      // a close always follows, and says what happened. Before the join,
      // keep what protocol.js said, such as a Galène version it cannot
      // speak, but not a socket error or a timeout, which say nothing.
      conn.onerror = function (e) {
        if (e && e.name === 'Error' && e.message && !/^(Socket error|Timeout)/.test(e.message)) why = e.message;
        if (joined) say('The connection failed.', true);
      };
      conn.connect(endpoint);
    } catch (e) {
      if (run !== gen) return;
      if (tries && tries < 3) {
        tries++;
        stop(true);
        rejoin = setTimeout(join, 1500 * tries);
        return;
      }
      fail(e);
      stop();
    }
  }

  $('mute').onclick = function () {
    muted = !muted;
    if (mic) mic.getAudioTracks().forEach(function (t) { t.enabled = !muted; });
    $('mute').textContent = muted ? 'Unmute' : 'Mute';
    $('mute').classList.toggle('on', muted);
    announce();
    render();
  };

  // each button waits for its device, so a second press makes no
  // second stream that nothing stops
  $('camera').onclick = async function () {
    if (cam) { stopTracks(cam); cam = null; return showVideo(); }
    $('camera').disabled = true;
    var run = gen;
    try {
      cam = await navigator.mediaDevices.getUserMedia({ video: { width: { ideal: 1280 }, height: { ideal: 720 } } });
    } catch (e) {
      say(e && e.name === 'NotAllowedError'
        ? 'The camera is blocked. Allow it in your browser, then press Start camera again.'
        : e && e.name === 'NotFoundError' ? 'No camera found.' : 'The camera is not available.', true);
      return;
    } finally {
      $('camera').disabled = false;
    }
    // the call ended while the browser was asking: let the camera go
    if (run !== gen) { stopTracks(cam); cam = null; return; }
    showVideo();
  };

  $('share').onclick = async function () {
    if (screen) { stopTracks(screen); screen = null; return showVideo(); }
    $('share').disabled = true;
    var run = gen;
    try {
      screen = await navigator.mediaDevices.getDisplayMedia({ video: true, audio: false });
    } catch (e) {
      return;
    } finally {
      $('share').disabled = false;
    }
    if (run !== gen) { stopTracks(screen); screen = null; return; }
    // The browser's own "Stop sharing" ends the track; go back to the camera.
    screen.getVideoTracks()[0].onended = function () { screen = null; showVideo(); };
    showVideo();
  };

  $('leave').onclick = function () { stop(); say('You left the call.'); };
  // one person, one seat: joining in another tab leaves this one, on
  // the call or about to rejoin it
  if (tabs) tabs.onmessage = function (e) {
    if (e.data === 'joined' && (conn || rejoin)) { stop(); say('You joined this call in another tab, so this one left.'); }
  };
  $('sound').onclick = function () {
    $('sound').hidden = true;
    [].slice.call(document.querySelectorAll('.tile video')).forEach(function (v) { v.play().catch(function () {}); });
  };
  $('form').onsubmit = join;

  function ready(room) {
    $('room').textContent = room.title || 'A call';
    document.title = (room.title || 'A call') + ' · Trunk';
    // on a call server the ship's address too, since a link may name any
    $('host').textContent = 'Hosted by ' + room.host + (onShip ? '' : ' at ' + host);
    speak = !!room.speak;
    $('name').value = recall('name') || '';
    $('form').hidden = false;
    // back from the ship after a Join, which only fetched a ticket
    var again = marked('again');
    if (!window.isSecureContext) say('This address is not secure, so your browser blocks the microphone and camera. You can still watch and listen.', true);
    else if (again) say('Press Join to go back on the call.');
    else say(speak ? 'You will be asked for your microphone. Headphones keep echo off the call.' : 'You can watch and listen on this call.');
  }

  if (onShip && location.hash === '#hop') {
    back();
  } else if (onShip) {
    fetch(base + '/room', { cache: 'no-store' })
      .then(function (r) { return r.json().then(function (j) { return [r.ok, j]; }); })
      .then(function (x) {
        if (!x[0]) throw new Error(x[1].error || 'This link has ended. Ask the host for a new one.');
        ready(x[1]);
      })
      .catch(fail);
  } else if (!/^[a-z0-9.-]+(:[0-9]+)?$/i.test(host || '') || !/^[a-z0-9-]+$/.test(code || '')) {
    say('This link is not complete. Ask the host for it again.', true);
  } else if (!hash[2] || !marked('hop')) {
    // the room and ticket only from the ship, after this tab asked
    hop();
  } else {
    try { given = JSON.parse(decodeURIComponent(hash[2])); } catch (e) { given = null; }
    got = Date.now();
    // the ticket is a bearer token for an hour, so not in the address bar
    history.replaceState(null, '', location.pathname + '#' + host + '/' + code);
    if (given && given.ticket) ready(given);
    else say('The host sent back something this page cannot read. Open the link again.', true);
  }
})();
