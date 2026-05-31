// tweaks-app.jsx — applies tweak values to the page + renders the panel.

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "accent": "#37A6FF",
  "font": "system",
  "grain": true,
  "parallax": 1
}/*EDITMODE-END*/;

function hexToRgb(hex) {
  const h = String(hex).replace('#', '');
  const x = h.length === 3 ? h.replace(/./g, (c) => c + c) : h;
  const n = parseInt(x, 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}
function mixHex(hex, target, amt) {
  const [r, g, b] = hexToRgb(hex);
  const m = (a, t) => Math.round(a + (t - a) * amt);
  const to2 = (v) => v.toString(16).padStart(2, '0');
  return `#${to2(m(r, target[0]))}${to2(m(g, target[1]))}${to2(m(b, target[2]))}`;
}

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);

  React.useEffect(() => {
    const root = document.documentElement;
    const [r, g, b] = hexToRgb(t.accent);
    root.style.setProperty('--amber', t.accent);
    root.style.setProperty('--accent', t.accent);
    root.style.setProperty('--amber-rgb', `${r},${g},${b}`);
    root.style.setProperty('--accent-rgb', `${r},${g},${b}`);
    root.style.setProperty('--amber-hi', mixHex(t.accent, [255, 255, 255], 0.42));
    root.style.setProperty('--amber-deep', mixHex(t.accent, [22, 14, 4], 0.46));
    root.setAttribute('data-font', t.font);
    root.style.setProperty('--grain', t.grain ? '0.6' : '0');
    root.style.setProperty('--scroll-mult', String(t.parallax));
    window.dispatchEvent(new CustomEvent('tweakchange'));
  }, [t]);

  return (
    <TweaksPanel title="Tweaks">
      <TweakSection label="主题" />
      <TweakColor label="氛围色" value={t.accent}
        options={['#FF8A1E', '#FF5A2C', '#E8A33D', '#A06CFF', '#37A6FF']}
        onChange={(v) => setTweak('accent', v)} />
      <TweakRadio label="显示字体" value={t.font}
        options={[{ value: 'system', label: '系统' }, { value: 'geometric', label: '几何' }, { value: 'editorial', label: '衬线' }]}
        onChange={(v) => setTweak('font', v)} />
      <TweakSection label="质感" />
      <TweakToggle label="胶片颗粒" value={t.grain} onChange={(v) => setTweak('grain', v)} />
      <TweakSlider label="滚动视差" value={t.parallax} min={0.4} max={1.6} step={0.1} unit="×"
        onChange={(v) => setTweak('parallax', v)} />
    </TweaksPanel>
  );
}

const __mount = document.createElement('div');
document.body.appendChild(__mount);
ReactDOM.createRoot(__mount).render(<App />);
