/* ─────────────────────────────────────────────────────────────
   StayAwake — scroll choreography (vanilla, rAF-driven)
   ───────────────────────────────────────────────────────────── */
(function () {
  'use strict';

  const $ = (s, r = document) => r.querySelector(s);
  const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
  const range = (x, a, b) => clamp((x - a) / (b - a), 0, 1);
  const smooth = (x) => x * x * (3 - 2 * x);
  const lerp = (a, b, t) => a + (b - a) * t;

  // hero
  const hero      = $('#hero');
  const heroIcon  = $('#heroIcon');
  const iconImg   = $('#iconImg');
  const bloom     = $('#bloom');
  const daybreak  = $('#daybreak');
  const beatNight = $('#beatNight');
  const beatDay   = $('#beatDay');
  const scrollhint= $('#scrollhint');
  // product
  const product   = $('#product');
  const panel     = $('#panel');
  const panelWrap = $('#panelWrap');
  const feats     = Array.from(document.querySelectorAll('.feat'));
  const nav       = $('#nav');
  const prog      = $('.prog');
  // flip interlude
  const flipSec   = $('#flipcta');
  const flipStage = $('#flipStage');
  const flipFlood = $('#flipFlood');
  const flipSw    = $('#flipSw');
  const flipKnob  = $('#flipKnob');
  const flipGlow  = $('#flipGlow');

  const featTargets = feats.map((f) =>
    (f.dataset.target || '').split(',').map((s) => s.trim()).filter(Boolean)
      .map((sel) => $(sel)).filter(Boolean));
  const allHot = Array.from(new Set(featTargets.flat()));

  // starfield
  (function () {
    const host = $('#stars');
    if (!host) return;
    let html = '';
    for (let i = 0; i < 80; i++) {
      const s = (0.6 + Math.random() * 1.7).toFixed(2);
      html += `<i style="left:${(Math.random() * 100).toFixed(1)}%;top:${(Math.random() * 72).toFixed(1)}%;width:${s}px;height:${s}px;animation-delay:${(Math.random() * 4).toFixed(2)}s"></i>`;
    }
    host.innerHTML = html;
  })();

  // tweakable CSS vars cache
  let accent = [255, 138, 30], mult = 1;
  function refreshVars() {
    const cs = getComputedStyle(document.documentElement);
    const rgb = cs.getPropertyValue('--accent-rgb').trim().split(',').map((n) => parseInt(n, 10));
    if (rgb.length === 3 && rgb.every((n) => !isNaN(n))) accent = rgb;
    const m = parseFloat(cs.getPropertyValue('--scroll-mult'));
    if (!isNaN(m)) mult = m;
  }
  refreshVars();
  window.addEventListener('tweakchange', () => { setTimeout(() => { refreshVars(); kick(); }, 0); });

  function tick() {
    dirty = false;
    const vh = window.innerHeight, doc = document.documentElement;

    const max = doc.scrollHeight - vh;
    prog.style.setProperty('--prog', max > 0 ? (window.scrollY / max).toFixed(4) : 0);

    // ── HERO ──────────────────────────────────────────────────
    let heroP = 0;
    if (hero) {
      const r = hero.getBoundingClientRect();
      heroP = clamp(-r.top / (r.height - vh), 0, 1);

      const nightOut = smooth(range(heroP, 0.20, 0.42));
      const ignite   = smooth(range(heroP, 0.28, 0.62));
      const dayIn    = smooth(range(heroP, 0.52, 0.74));
      const hintOut  = range(heroP, 0.02, 0.12);

      const flood = smooth(range(heroP, 0.50, 0.74));
      const b = lerp(0.5, 1, ignite).toFixed(3);
      const s = lerp(0.45, 1, ignite).toFixed(3);
      const shY = (16 + ignite * 22) | 0, shB = (34 + ignite * 34) | 0;
      const shA = (0.12 + flood * 0.16).toFixed(3);
      iconImg.style.filter =
        `brightness(${b}) saturate(${s}) drop-shadow(0 ${shY}px ${shB}px rgba(18,20,30,${shA}))`;
      // bloom rises with ignition, then settles to a faint warm glow on white
      bloom.style.opacity = lerp(ignite * 0.9, 0.16, flood).toFixed(3);
      // white daylight floods out from the igniting icon
      if (daybreak) daybreak.style.clipPath = `circle(${(ignite * 150).toFixed(1)}vmax at 64% 50%)`;
      // icon: low-center & smaller at night (clear of the headline) → settles right on day
      const moveX = (ignite * 23 * mult).toFixed(2);
      const moveY = (lerp(21, -2, ignite) * mult).toFixed(2);
      const sc = lerp(0.74, 0.88, ignite).toFixed(3);
      heroIcon.style.transform =
        `translate(calc(-50% + ${moveX}vw), calc(-50% + ${moveY}vh)) scale(${sc})`;

      beatNight.style.opacity = (1 - nightOut).toFixed(3);
      beatNight.style.transform = `translateX(-50%) translateY(${(-nightOut * 40 * mult).toFixed(1)}px)`;
      beatDay.style.opacity = dayIn.toFixed(3);
      beatDay.style.transform = `translateY(calc(-50% + ${((1 - dayIn) * 24 * mult).toFixed(1)}px))`;

      scrollhint.style.opacity = (1 - hintOut).toFixed(3);
    }

    // ── PRODUCT ───────────────────────────────────────────────
    if (product) {
      const r = product.getBoundingClientRect();
      const p = clamp(-r.top / (r.height - vh), 0, 1);
      const n = feats.length;

      feats.forEach((f, i) => {
        const center = (i + 0.5) / n;
        const op = clamp(1 - Math.abs(p - center) / (0.92 / n), 0, 1);
        f.style.opacity = smooth(op).toFixed(3);
        f.style.transform = `translateY(${((p - center) * 70 * mult).toFixed(1)}px)`;
        f.style.pointerEvents = op > 0.5 ? 'auto' : 'none';
      });

      const active = clamp(Math.floor(p * n), 0, n - 1);
      const tilt = (p - 0.5) * 6;
      panelWrap.style.transform = `translateY(${((p - 0.5) * -22 * mult).toFixed(1)}px)`;
      panel.style.transform = `rotateX(${(tilt * 0.35).toFixed(2)}deg) rotateY(${(-tilt).toFixed(2)}deg)`;

      const hot = new Set(featTargets[active] || []);
      allHot.forEach((el) => el.classList.toggle('hot', hot.has(el)));
    }

    // ── FLIP INTERLUDE ────────────────────────────────────────
    if (flipSec) {
      const r = flipSec.getBoundingClientRect();
      const p = clamp(-r.top / (r.height - vh), 0, 1);
      const knobP = smooth(range(p, 0.16, 0.52));
      const flood = smooth(range(p, 0.46, 0.92));
      const pad = flipSw.clientWidth * 0.07;
      const travel = Math.max(0, flipSw.clientWidth - flipKnob.offsetWidth - pad * 2);
      flipKnob.style.transform = `translateX(${(travel * knobP).toFixed(1)}px)`;
      const [ar, ag, ab] = accent;
      flipSw.style.background = `rgba(${lerp(176, ar, knobP) | 0},${lerp(176, ag, knobP) | 0},${lerp(180, ab, knobP) | 0},${(0.26 + 0.74 * knobP).toFixed(3)})`;
      flipGlow.style.opacity = (knobP * 0.9).toFixed(3);
      flipFlood.style.clipPath = `circle(${(flood * 150).toFixed(1)}vmax at 50% 50%)`;
      flipStage.classList.toggle('flooded', flood > 0.5);
    }

    // ── NAV theme ─────────────────────────────────────────────
    const centerY = vh / 2;
    let light = false;
    document.querySelectorAll('[data-scene]').forEach((sec) => {
      const r = sec.getBoundingClientRect();
      if (r.top <= centerY && r.bottom >= centerY) {
        if (sec === hero) light = heroP > 0.50;
        else if (sec === flipSec) light = !flipStage.classList.contains('flooded');
        else light = sec.dataset.scene === 'day';
      }
    });
    nav.dataset.onLight = light ? '1' : '0';
  }

  let dirty = true;
  function kick() { if (!dirty) { dirty = true; requestAnimationFrame(tick); } }
  window.addEventListener('scroll', kick, { passive: true });
  window.addEventListener('resize', () => { dirty = true; requestAnimationFrame(tick); });
  window.addEventListener('load', () => { requestAnimationFrame(tick); });
  requestAnimationFrame(tick);
})();
