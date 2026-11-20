// Scroll reveal, the LunariaOS way: a block fades and lifts in when it scrolls into view,
// resets once it is fully off screen, and plays again the next time you come back.
// Blocks that arrive together are staggered. Loaded in <head> so .js is set before first paint;
// without JS (or with reduced motion, see style.css) everything is simply shown.
document.documentElement.classList.add('js');
addEventListener('DOMContentLoaded', () => {
  // Tag the parts of each section: titles, text and buttons move on their own, while pictures,
  // cards, lists and steps move as one piece. A wrapper marked .reveal hands the motion to its parts.
  // Load-in heroes (.rise, .sp-hero) keep their own animation.
  const atoms = 'figure, .cell, .list, .qs, .steps > li, .phases > li';
  document.querySelectorAll(`main section :is(.label, h2, .lede, .actions, .tag, ${atoms})`).forEach(el => el.classList.add('reveal'));
  const drop = el => el.classList.remove('reveal');
  document.querySelectorAll('.reveal').forEach(el => { if (el.closest('.rise, .sp-hero') || el.parentElement.closest(atoms)) drop(el); });
  document.querySelectorAll('.reveal').forEach(el => { if (el.querySelector('.reveal')) drop(el); });
  const blocks = [...document.querySelectorAll('.reveal')];
  // Shown once it is 12% up from the bottom edge; reset once it has fully left the screen.
  const show = new IntersectionObserver(entries => {
    entries.filter(e => e.isIntersecting && !e.target.classList.contains('in'))
      .forEach((e, i) => { e.target.style.setProperty('--delay', `${Math.min(i, 5) * 90}ms`); e.target.classList.add('in'); });
  }, { rootMargin: '0px 0px -12% 0px' });
  const hide = new IntersectionObserver(entries => {
    entries.forEach(e => { if (!e.isIntersecting) e.target.classList.remove('in'); });
  });
  blocks.forEach(el => { show.observe(el); hide.observe(el); });
});
