Querator — CS2 Match Plugin
==============

**Querator** is [Lany](https://lany.gg)'s fork of [MatchZy](https://github.com/shobhit-pathak/MatchZy) — a
[CounterStrikeSharp](https://github.com/roflmuffin/CounterStrikeSharp) plugin for CS2 (Counter-Strike 2) that runs and
manages practice / pugs / scrims / matches. It powers match orchestration on Lany's servers and is maintained for
Lany's own needs.

> **Querator is a fork of MatchZy** by shobhit-pathak ("WD-"), used under the MIT License. The lineage is kept on
> purpose — see [`CREDITS`](CREDITS) and [`LICENSE`](LICENSE). Internal engineering docs live in
> [`docs/`](docs/00-index.md); the rebrand from MatchZy → Querator is complete and live in production as of
> 2026-06-25 (Querator 1.0.0 — see [`docs/00-REBRAND-LOG.md`](docs/00-REBRAND-LOG.md)).

## Feature highlights

* Pug mode with simple chat commands (`.ready`, `.pause`, `.stop`, `.tac`, …)
* BO1 / BO3 / BO5 with map veto (via match configuration)
* Match setup that locks players into their teams/sides
* Practice mode (`.bot`, `.spawn`, `.ctspawn`, `.tspawn`, `.nobots`, `.rethrow`, `.last`, `.timer`, `.clear`,
  `.exitprac`, and more)
* Knife round (most-alive → most-HP → random)
* Automatic GOTV demo recording + upload on map end (`tv_enable 1`)
* Player whitelisting, coaching system, per-round damage report, round restore/backups
* Admin system, SQLite/MySQL match stats, and CSV export
* And much more

## Documentation

* **Engineering reference (internal):** [`docs/`](docs/00-index.md) — architecture, lifecycle, commands, persistence, etc.
* **User docs (MkDocs):** [`documentation/`](documentation/)

## Credits

Querator is built on **[MatchZy](https://github.com/shobhit-pathak/MatchZy)** by shobhit-pathak ("WD-") — huge thanks
for the foundation. MatchZy in turn credits [Get5](https://github.com/splewis/get5),
[G5V/G5API](https://github.com/PhlexPlexico/G5V), [eBot](https://github.com/deStrO/eBot-CSGO),
[CounterStrikeSharp](https://github.com/roflmuffin/CounterStrikeSharp/), the AlliedModders community, and contributors
CHR15cs, K4ryuu, and DEAFPS. Full attribution in [`CREDITS`](CREDITS).

## License

MIT — see [`LICENSE`](LICENSE).
