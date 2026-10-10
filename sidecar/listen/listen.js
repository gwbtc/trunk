// The listen page's script. It sits in its own file because Galène
// serves /listen/ with a Content-Security-Policy of script-src 'self',
// which blocks inline scripts: inline, the page did nothing.
(function () {
  var params = new URLSearchParams(location.search);
  var token = params.get('token');
  // The subgroup rides in the token's aud (<base>/group/<subgroup>/),
  // so the link doesn't spell it, nor the host @p inside it. A link
  // minted before wire 10 still says group=.
  var group = params.get('group') || audGroup(token);

  var goBtn = document.getElementById('go');
  var statusEl = document.getElementById('status');
  var roomEl = document.getElementById('room');
  var whoEl = document.getElementById('who');
  var whoList = document.getElementById('whoList');
  var sinks = document.getElementById('sinks');

  var conn = null;
  var speaking = {};
  // stream id -> { s: the down stream, rs: [RTCRtpReceiver] }.
  //
  // Keyed by stream rather than by publisher name: protocol.js may not
  // have filled in s.username by the time ondowntrack fires, and a name
  // captured then could be the 'someone' fallback forever — a dot that
  // never lands on a row anybody displays. Resolving the name at poll
  // time costs nothing and is always current.
  var streams = {};
  var muted = {};
  var elements = {};
  var ctx = null;
  var speakTimer = null;

  function audGroup(tok) {
    try {
      var b = tok.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
      var aud = JSON.parse(atob(b)).aud;
      var m = /\/group\/(.+?)\/?$/.exec(Array.isArray(aud) ? aud[0] : aud);
      return m ? m[1] : null;
    } catch (e) {
      return null;
    }
  }

  /**
   * The name to show for a username. Galène's username is the @p the
   * host signed into the token. A client may add a readable name in
   * its per-user data ({"name": ...}), which wins. Hosts on wire 10 to
   * 12 signed a comet in as its full mnemonym (.a.b.….l), shown in the
   * two-word form Talon shows. A guest (wire 16) is signed in as
   * guest-<hex> and is always marked, so nobody passes as a ship by
   * the name they typed.
   */
  function label(u, n) {
    var d = u && u.data;
    var shown = (d && typeof d.name === 'string' && d.name) ? d.name : short(n);
    return /^guest-/.test(n || '') ? shown + ' (guest)' : shown;
  }

  function short(n) {
    var m = /^(\.\.?)([a-z]+)\..*\.([a-z]+)$/.exec(n);
    return m ? m[1] + m[2] + '...' + m[3] : n;
  }

  /**
   * Take the gesture and hold it.
   *
   * An <audio> created later — when a track finally arrives, seconds
   * after the click — does not carry the click's activation, and
   * play() is refused with NotAllowedError. An AudioContext resumed
   * inside the click stays resumed, and sources attached to it
   * afterwards need no further gesture.
   */
  function unlock() {
    try {
      var Ctx = window.AudioContext || window.webkitAudioContext;
      if (!ctx && Ctx) ctx = new Ctx();
      if (ctx && ctx.state === 'suspended') ctx.resume();
    } catch (e) {
      trace('no audio context');
    }
  }

  /**
   * One element per stream, so several speakers are all audible: an
   * <audio> with a multi-track MediaStream plays only the first track
   * in Chrome.
   *
   * Uses the MediaStream protocol.js received with the track, rather
   * than a hand-built one — that is what Galene's own client attaches,
   * and a stream assembled by hand does not reliably play.
   */
  function play(id, mediaStream) {
    if (!mediaStream) { trace('track with no stream'); return; }
    if (elements[id]) return;

    // Chrome will not pump a WebRTC stream that is only wired into an
    // AudioContext, so the stream is also parked on a MUTED element.
    // That element is silent by design — the sound comes out of the
    // context below, which the click already unlocked.
    var pump = document.createElement('audio');
    pump.muted = true;
    pump.autoplay = true;
    pump.playsInline = true;
    pump.srcObject = mediaStream;
    sinks.appendChild(pump);
    var pp = pump.play();
    if (pp && pp.catch) pp.catch(function () { /* muted; harmless */ });

    if (!ctx) {
      trace('no audio context');
      say('This browser cannot play the line.', true);
      return;
    }
    try {
      var src = ctx.createMediaStreamSource(mediaStream);
      src.connect(ctx.destination);
      // who is talking is measured on the sound we play (see
      // +startSpeakingPoll)
      var an = ctx.createAnalyser();
      an.fftSize = 2048;
      src.connect(an);
      elements[id] = { pump: pump, src: src, an: an };
      if (ctx.state === 'suspended') ctx.resume();
      trace('playing');
    } catch (e) {
      trace('routing failed: ' + (e && e.name));
      say('Could not route the audio.', true);
    }
  }

  var traceEl = document.getElementById('trace');
  var steps = [];
  /** Say where we got to, so a silent page is still diagnosable. */
  function trace(step) {
    steps.push(step);
    if (steps.length > 4) steps.shift();
    traceEl.textContent = steps.join(' · ');
  }

  function say(text, bad) {
    statusEl.textContent = text;
    statusEl.className = bad ? 'status bad' : 'status';
  }

  if (!group || !token) {
    roomEl.textContent = 'Bad link';
    goBtn.disabled = true;
    say('This link is missing its room or its token.', true);
    return;
  }
  var host = params.get('host');
  var room = params.get('room');
  roomEl.textContent = room
    ? (host ? host + ' ' : '') + room.replace(/-/g, ' ')
    : group.split('/').pop().replace(/-/g, ' ');
  var topic = params.get('topic');
  if (topic) {
    document.getElementById('topic').textContent = topic;
    document.getElementById('topic').hidden = false;
  }

  // protocol.js maintains conn.users itself; onuser is only a
  // notification and carries (id, kind) — no username. Reading a
  // third argument that isn't there is why this list was empty.
  //
  // 'present' separates people on the line from other listeners:
  // a listener holds no permissions at all.
  function renderWho() {
    var us = (conn && conn.users) || {};
    var names = [];
    var labels = {};
    var others = 0;
    Object.keys(us).forEach(function (id) {
      var u = us[id] || {};
      var perms = u.permissions || [];
      if (perms.indexOf('present') >= 0) {
        // One row per person, not per connection. Someone signed in
        // on two devices is still one person on the line. Rows are
        // keyed by username, the signed identity, never by the name
        // shown, which anyone can choose.
        var n = u.username || id;
        if (names.indexOf(n) < 0) names.push(n);
        if (!labels[n] || labels[n] === short(n)) labels[n] = label(u, n);
      } else {
        others++;
      }
    });
    whoEl.hidden = names.length === 0 && others === 0;
    whoList.innerHTML = '';
    names.sort(function (a, b) {
      return labels[a] < labels[b] ? -1 : labels[a] > labels[b] ? 1 : 0;
    }).forEach(function (n) {
      var li = document.createElement('li');
      var dot = document.createElement('span');
      dot.className = speaking[n] ? 'dot on' : 'dot';
      li.appendChild(dot);
      li.appendChild(document.createTextNode(labels[n]));
      // Only the muted are marked: everyone here is expected to be able
      // to talk, so a mic on every row would be a column of noise.
      if (muted[n]) {
        var m = document.createElement('span');
        m.className = 'muted';
        m.title = 'Muted';
        m.textContent = 'muted';
        li.appendChild(m);
      }
      whoList.appendChild(li);
    });
    if (others > 0) {
      var li = document.createElement('li');
      li.style.opacity = '.7';
      li.appendChild(document.createTextNode(
        others === 1 ? 'and 1 listening' : 'and ' + others + ' listening'));
      whoList.appendChild(li);
    }
  }

  /**
   * Who is talking, measured on the sound this page plays. Galène does
   * not negotiate the RTP audio-level extension, so the receivers report
   * no level, and audio routed through an AudioContext never reaches
   * WebRTC's own level counter either.
   */
  function startSpeakingPoll() {
    if (speakTimer) return;
    var buf = new Float32Array(2048);
    var heard = {};   // by name: when they were last loud
    speakTimer = setInterval(function () {
      var now = {};
      var t = Date.now();
      Object.keys(streams).forEach(function (id) {
        var e = streams[id], el = elements[id];
        var name = e && e.s && e.s.username;
        if (!name || !el || !el.an) return;
        el.an.getFloatTimeDomainData(buf);
        var sum = 0;
        for (var i = 0; i < buf.length; i++) sum += buf[i] * buf[i];
        if (Math.sqrt(sum / buf.length) > 0.02) heard[name] = t;
        // held a moment past the last loud sample, so the dot does not
        // flicker between words
        now[name] = now[name] || (t - (heard[name] || 0) < 600);
      });
      var changed = false;
      Object.keys(now).forEach(function (name) {
        if (!!speaking[name] !== now[name]) { speaking[name] = now[name]; changed = true; }
      });
      if (changed) renderWho();
    }, 250);
  }

  function stop() {
    if (conn) { try { conn.close(); } catch (e) {} conn = null; }
    if (speakTimer) { clearInterval(speakTimer); speakTimer = null; }
    Object.keys(elements).forEach(function (k) {
      try { elements[k].src.disconnect(); } catch (e) {}
    });
    sinks.innerHTML = '';
    elements = {};
    speaking = {};
    streams = {};
    muted = {};
    renderWho();
    goBtn.textContent = 'Listen';
    goBtn.className = '';
    goBtn.disabled = false;
    goBtn.onclick = start;
  }

  function start() {
    goBtn.disabled = true;
    say('Connecting…');

    // The click is the autoplay gesture: play one silent element now
    // so the page is unlocked, and every element made afterwards can
    // start on its own.
    unlock();

    conn = new ServerConnection();

    conn.onconnected = function () {
      this.join(group, 'listener', { type: 'token', token: token });
    };

    conn.onjoined = function (kind, g, perms, status, data, error, message) {
      if (kind === 'fail' || kind === 'redirect') {
        say(message || error || 'The host refused this link.', true);
        stop();
        return;
      }
      if (kind !== 'join') return;
      // Ask for every audio stream on the line.
      trace('joined');
      this.request({ '': ['audio'] });
      trace('asked for audio');
      say('Listening. Nothing to hear yet.');
      goBtn.textContent = 'Stop listening';
      goBtn.className = 'leave';
      goBtn.disabled = false;
      goBtn.onclick = function () { stop(); say('Stopped.'); };
    };

    // (id, kind) only — the user record lives in conn.users.
    conn.onuser = function () { renderWho(); };

    // Mic state, broadcast by Talon clients. Galène relays kinds it
    // doesn't recognise, so this needs nothing from the server; a room
    // with no Talon clients simply never sets it.
    conn.onusermessage = function (source, dest, username, time, privileged, kind, error, value) {
      if (kind !== 'talon-mute' || !username) return;
      // Keyed by the name Galène gave the sending connection, which is
      // the name the list shows. `username` is whatever the client
      // wrote (Talon writes its @p), and Galène checks only `source`.
      var u = conn.users[source];
      muted[(u && u.username) || username] = !!value;
      renderWho();
    };

    conn.ondownstream = function (s) {
      trace('stream offered');
      s.onstatus = function (st) {
        trace('stream ' + st);
        if (st === 'connected') say('Listening');
      };
      s.ondowntrack = function (track, transceiver, stream_) {
        // Hold the stream, not its name — see the `streams` comment.
        var e = streams[s.id] || (streams[s.id] = { s: s, rs: [] });
        e.s = s;
        e.rs.push(transceiver.receiver);
        startSpeakingPoll();
        trace('track from ' + (s.username || 'someone'));
        play(s.id, s.stream || stream_);
        say('Listening');
      };
      s.onclose = function () { say('Listening. Nothing to hear yet.'); };
    };

    conn.onclose = function () {
      say('The line ended.');
      stop();
    };

    conn.onerror = function (e) {
      say((e && e.message) || 'Connection failed.', true);
      stop();
    };

    // Galène tells us its websocket endpoint in the group's status.
    fetch('/group/' + group + '/.status')
      .then(function (r) { return r.json(); })
      .then(function (st) { conn.connect(st.endpoint); })
      .catch(function () {
        say('Could not reach the server.', true);
        stop();
      });
  }

  goBtn.onclick = start;
})();
