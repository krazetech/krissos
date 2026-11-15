# kriss-welcome data sources

| File | Source | Licence | Bundled? |
|---|---|---|---|
| `games.json` | [AreWeAntiCheatYet](https://github.com/AreWeAntiCheatYet/AreWeAntiCheatYet) `games.json`, trimmed to name, slug, status, anti-cheats, first note and Steam id | MIT (notice below) | Yes. Refresh with `python welcome/data/refresh-games.py` |
| ProtonDB ratings | [protondb.com](https://www.protondb.com) | No licence on the ratings or the API. The [data dumps](https://github.com/bdefore/protondb-data) are ODbL but hold raw reports, not the tiers | **No, linked.** Each game with a Steam id links to `protondb.com/app/<id>` |
| `apps.json` | Written by the KrissOS team; Flathub ids checked against `flathub.org/api/v2/appstream/<id>` | GPL-3.0-or-later, like the rest of the repo | Yes. Entries with `"uncertain": true` are best-effort and need real-world testing |

The anti-cheat statuses are AreWeAntiCheatYet's: Supported (anti-cheat on Linux is enabled by
the developer), Running (runs, not officially supported), Planned, Broken, Denied (the developer
blocks Linux on purpose).

## AreWeAntiCheatYet licence

```
MIT License

Copyright © 2021 Starz0r, Curve

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
