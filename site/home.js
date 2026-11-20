// Home page: words of the statement light up as it scrolls by, and the sticky
// wallpaper story runs the Sungai Petani clock from 07:30 to 19:30.
// ponytail: one scroll listener, rAF-throttled; no library.
const say = document.querySelector('[data-words]');
if (say) say.innerHTML = say.textContent.trim().split(/\s+/).map(w => `<span class="w">${w}</span>`).join(' ');
const words = say ? [...say.querySelectorAll('.w')] : [];
const sun = document.querySelector('[data-sun]');
const night = sun?.querySelector('[data-night]');
const clock = sun?.querySelector('[data-clock]');
const steps = sun ? [...sun.querySelectorAll('[data-step]')] : [];
const clamp = x => Math.min(1, Math.max(0, x));

function frame() {
  const vh = innerHeight;
  if (say) {
    const r = say.getBoundingClientRect();
    const p = clamp((vh * .85 - r.top) / (r.height + vh * .35));
    words.forEach((w, i) => w.classList.toggle('on', i < p * words.length));
  }
  if (sun) {
    const r = sun.getBoundingClientRect();
    const p = clamp(-r.top / (r.height - vh) * 1.1); // reach 19:30 a little before the end
    const mins = 7.5 * 60 + p * 12 * 60; // 07:30 to 19:30
    clock.textContent = `${String(Math.floor(mins / 60)).padStart(2, '0')}:${String(Math.floor(mins % 60 / 5) * 5).padStart(2, '0')}`;
    night.style.setProperty('--p', clamp((mins - 1050) / 120)); // the shell blends 17:30 to 19:30
    const s = mins < 1050 ? 0 : mins < 1170 ? 1 : 2;
    steps.forEach((li, i) => li.classList.toggle('on', i === s));
  }
}
let queued = false;
addEventListener('scroll', () => { if (!queued) { queued = true; requestAnimationFrame(() => { queued = false; frame(); }); } }, { passive: true });
addEventListener('resize', frame);
frame();

// Numbers roll into place once, when the tiles come into view.
const tiles = document.querySelector('.tiles');
if (tiles && 'IntersectionObserver' in window) {
  tiles.classList.add('wait');
  new IntersectionObserver(([e], o) => {
    if (e.isIntersecting) { tiles.classList.replace('wait', 'go'); o.disconnect(); }
  }, { threshold: .5 }).observe(tiles);
}
