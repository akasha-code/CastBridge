<div align="center">

[English](README.md) · [Español](README.es.md) · **Norsk**

![CastBridge — En produksjon fra MateKraft](assets/castbridge-banner.svg)

# CastBridge

### Mer plass til arbeidet som betyr noe.

Utvid Windows-skrivebordet til en Chromecast.<br />
**En produksjon fra [MateKraft](https://matekraft.tech).**

[Last ned forhåndsversjon](docs/downloads.no.md) · [Installasjonsveiledning på engelsk](INSTALL.md) · [Rapporter et problem](https://github.com/akasha-code/CastBridge/issues)

[matekraft.tech](https://matekraft.tech) · [Buy me a coffee](https://www.buymeacoffee.com/matekraft)

</div>

## Hva programmet gjør

CastBridge oppretter en midlertidig skjerm på 1280 × 720 og sender dette skrivebordet til den valgte Chromecast-enheten via det lokale nettverket. Flytt et vindu til den ekstra skjermen og styr det med PC-ens mus og tastatur. Ved normal frakobling fjernes den midlertidige skjermen, og oppsettet for de fysiske skjermene gjenopprettes.

- Velg mottaker og navnet som vises på TV-en.
- Behold plasseringen av den virtuelle skjermen for hver mottaker.
- Velg engelsk, spansk eller norsk bokmål; språkvalget lagres.
- Velg Stabil, Redusert eller Minimum eksperimentell forsinkelsesprofil.
- Etter låsing eller hvilemodus viser en avbrutt aktiv økt et tilkoblingsvindu med ti sekunders nedtelling. Koble til samme mottaker nå, avbryt eller la tiden løpe ut.
- Finn versjonen, prosjektet og MateKrafts nettsted under **Om CastBridge**.

## Installasjon

1. Last ned **CastBridge-Setup.exe** fra den nyeste forhåndsversjonen.
2. Åpne filen, velg språk og kontroller kravene.
3. Velg et manglende krav for instruksjoner og en offisiell nedlastingslenke. Klargjør eksterne verktøy, og kontroller på nytt.
4. Når alle krav er oppfylt, installer og åpne **CastBridge** fra Start-menyen.

Installasjonsprogrammet og grensesnittet er kompilerte Windows-programmer. Den installerte pakken inneholder ingen PowerShell-skript. Programmet bruker den eksisterende overføringsmotoren i Python og en innebygd hjelpekomponent for den midlertidige skjermen.

Du trenger **Windows 11 x64**, **Python 3.12 x64 med py-starteren**, **FFmpeg med gdigrab, libx264 og HLS**, en kompatibel og signert **Virtual Display Driver 25.7.23** i Windows Driver Store, riktig skjermkonfigurasjon og HTTPS-tilgang for nedlasting av Python-avhengigheter. Kravene kontrolleres før programfiler kopieres. Eksterne verktøy klargjøres separat; installasjonsprogrammet gir veiledning.

**Forhåndsversjon:** programfilene er foreløpig ikke digitalt signert. En kompilert fil erstatter ikke bekreftelse av utgiveren. Nedlastingene er private under valideringen og krever tilgang til GitHub.

## Bruk

Velg mottaker og koble til. Windows ber om administratortillatelse for å aktivere den midlertidige skjermen. Flytt vinduer til den ekstra skjermen som på et vanlig utvidet skrivebord. Når vinduet lukkes, er CastBridge fortsatt tilgjengelig i systemstatusfeltet.

Endre forsinkelsesprofilen mens du er frakoblet. **Hopp til direkte** gjentar synkroniseringen under en økt. Bruk **Koble fra** og vent til oppryddingen er ferdig før du avslutter.

## Nåværende begrensninger

Dette er en eksperimentell skrivebordsutvidelse. Flere manuelle økter viste omtrent 2,8–3,8 sekunders forsinkelse; resultatet avhenger av mottakeren og nettverket. En ren installasjon på en annen PC, hvilemodus og gjenoppretting etter nettverksbrudd må fortsatt valideres.

Videostrømmen lagres i minnet og leveres over lokal HTTP med et token og tilgang begrenset til valgt mottaker. Transporten er ikke kryptert. CastBridge endrer ikke automatisk brannmur, sertifikater, PATH eller sikkerhetsinnstillinger. Mottakertilgangen kontrolleres ved tilkobling, ikke under installasjonen.

Avinstaller via **Installerte apper** i Windows. Eksterne verktøy, lokale innstillinger og logger beholdes. Ikke tvangsavslutt programmet under en aktiv økt.

## Utvikling og verifisering

C#-grensesnittet bruker .NET Framework på støttede Windows 11-systemer. Byggingen bruker Windows' C#-kompilator og GCC x64 for den innebygde hjelpekomponenten.

```powershell
.\scripts\Build-NativeHelper.ps1
.\scripts\Build-Icon.ps1
.\scripts\Build-Portable.ps1
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

Utviklingsskriptene bruker PowerShell; de distribuerte programfilene starter det ikke. Grensesnittet og installasjonsprogrammet ligger i `native/`, motoren i `prototype/`, og oversettelsene i `assets/languages.json`. Interne enhetsidentifikatorer beholdes for kompatibilitet med eksisterende innstillinger.

## Lisens og kreditering

CastBridges originale kode, dokumentasjon og grafikk laget for prosjektet er lisensiert under [Apache License 2.0](LICENSE). Se [NOTICE](NOTICE) for opphavsrett og kreditering av MateKraft, og [TRADEMARKS.md](TRADEMARKS.md) for navne- og merkepolicyen.

Avhengigheter beholder sine egne lisenser. [Tredjepartsmerknader](THIRD_PARTY_NOTICES.md) dokumenterer pakkene og eksterne verktøy; lisensene finnes i [third_party/licenses](third_party/licenses). Apache-2.0 erstatter ikke disse lisensene.

## La oss starte med en meningsfull samtale

Nyttige verktøy begynner med et reelt problem. Hvis CastBridge hjelper deg, eller du har en konkret idé til forbedring, la oss snakke sammen.

En kort melding er nok. Vi tar det derfra.

[Start samtalen](https://tally.so/r/J929pK) · [Besøk MateKraft](https://matekraft.tech) · [Opprett en sak](https://github.com/akasha-code/CastBridge/issues)

[![Støtt MateKraft — Buy me a coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-MateKraft-D4AF37?style=for-the-badge&logo=buymeacoffee&logoColor=0a1412)](https://www.buymeacoffee.com/matekraft)

Støtte er frivillig og endrer ikke programmets funksjonalitet.
