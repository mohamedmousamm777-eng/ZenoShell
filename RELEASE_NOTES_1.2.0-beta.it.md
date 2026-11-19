# ZenoShell 1.2.0 beta

L'aggiornamento più grande finora: sfondi animati, un vero Audio Center, un System Monitor, un pannello meteo con mappa vera, un lanciatore unico, tre nuovi look per la barra Classic, profilo e stili del blocco schermo, e circa metà della RAM.

> Questa è una **beta**. Tutto è scritto per niri e Hyprland su Arch Linux. Segnala quello che non funziona.

## Novità

### Sfondi animati
- Video e GIF girano dentro la shell (Qt Multimedia, sempre muti), un player per monitor, sopra lo sfondo fisso.
- `Alt+Shift+W` ne sceglie uno, `Alt+W` o **Stop** nelle Impostazioni lo ferma. Il fotogramma fisso è lo sfondo normale e la base dei colori pywal.
- **Pausa intelligente**: smette di decodificare con una finestra a schermo intero, sul blocco schermo, con lo schermo spento, in Game Mode ed Eco Mode, e quando il PC è sotto carico (CPU > 85% o RAM > 90%). Si attiva nelle Impostazioni.
- Per i video serve `qt6-multimedia-ffmpeg`. Senza, la shell parte lo stesso e le GIF funzionano.

### Audio Center (`Alt+A`, `Alt+Shift+A`)
- Equalizzatore di sistema su filtro PipeWire, con preset e bilanciamento sinistra/destra.
- Quattro aspetti, uno per ogni stile di barra. La curva passa sopra le pillole, con manopole da cliccare e trascinare.
- Una striscia musica sfocata sopra l'equalizzatore.

### System Monitor (`Alt+M`)
- Sei riquadri (CPU, RAM, GPU, temperatura, processi, rete) e sei viste di dettaglio.
- Legge **tutte** le schede grafiche, anche quella integrata nella CPU.
- Legge solo mentre è aperto e si chiude solo con un clic fuori.

### Meteo e mappa (`Alt+Shift+M`)
- Mappa vera (tessere OpenStreetMap / CARTO) con strati meteo, previsioni e qualità dell'aria da Open-Meteo.
- Chiede il permesso prima di usare la posizione. Pagina nelle Impostazioni: attiva/disattiva, luogo, unità e lingua, fonte della mappa e aggiornamento.

### Lanciatore
- Un'unica lista che unisce app, risultati tipo calcolatrice e ricerca web (nel browser attuale, con motori come `g`, `ddg`, `yt`, `gh`, `wp`, `mp`).

### Barra Classic: tre nuovi look (`Alt+V`)
- **Full**: barra trasparente, statistiche, titolo finestra, notch con i workspace in kanji, tray e batteria.
- **Capsules**: capsule colorate dentro contenitori scuri.
- **Floating + dock**: riquadri arrotondati separati e un dock con app preferite e aperte.
- I colori seguono il tema pywal. Si vedono app aperte e icone di sistema.

### Profilo e blocco schermo
- Nuova prima pagina nelle Impostazioni: **Profile & lock screen**. Nome, luogo, forma della foto e un piccolo selettore con un cerchio per ogni foto in `~/Immagini/Profile`.
- Tre stili di blocco: **Classic**, **Giant clock** (pillola col lucchetto che si riempie di puntini) e **Terminal**.
- Orologio e campo di login si spostano in nove posizioni. Un pulsante **Test lock** sicuro si sblocca da solo dopo 12 secondi.

### RAM e stabilità
- Circa metà della RAM: pagine e pannelli nascono solo quando li apri e vengono liberati un minuto dopo (da circa 251 MB a 138 MB di memoria privata nei nostri test).
- La shell parte con `qs -n`: una seconda copia non può più partire per errore.
- Night light corretta: ripristina lo stato all'avvio e ferma i `gammastep` rimasti.

## Scorciatoie aggiunte
`Alt+A` Audio Center · `Alt+Shift+A` equalizzatore · `Alt+M` System Monitor · `Alt+Shift+M` meteo · `Alt+V` look Classic / versione Dashboard · `Alt+Shift+W` sfondo animato · `Alt+O` Impostazioni

## Aggiornare
```
cd ~/quickshell-dots && git pull
```
poi rilancia l'installer, oppure copia a mano le cartelle `quickshell`, `niri` e `hypr`, e riavvia con `qs kill; sleep 2; qs -n -d`.
