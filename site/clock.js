// The footer clock shows the time in Sungai Petani, like the lock screen does at home.
const myt = document.querySelector('[data-myt]');
const fmt = new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Kuala_Lumpur', hour: '2-digit', minute: '2-digit' });
const tick = () => { myt.textContent = fmt.format(new Date()); };
if (myt) { tick(); setInterval(tick, 10000); }
