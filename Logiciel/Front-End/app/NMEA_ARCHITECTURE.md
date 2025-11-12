# Architecture NMEA 0183 Integration

## Diagramme de Flux Complet

```mermaid
graph TB
    subgraph Bateau ["🚤 Bateau - Réseau WiFi"]
        Miniplexe["Miniplexe 2Wi<br/>(NMEA 0183 UDP)"]
        Instruments["Instruments Nautiques<br/>(Anémomètre, GPS, etc.)"]
        Instruments -->|Sentences NMEA| Miniplexe
        Miniplexe -->|UDP Broadcast<br/>Port 10110| Network["WiFi Réseau Interne<br/>192.168.1.x"]
    end

    subgraph App ["📱 Application Kornog"]
        Config["🔧 Configuration<br/>TelemetryNetworkConfig"]
        Selection["Sélecteur Mode<br/>telemetrySourceModeProvider"]
        
        subgraph Buses ["Telemetry Buses"]
            FakeBus["FakeTelemetryBus<br/>(Simulation)"]
            NetworkBus["NetworkTelemetryBus<br/>(NMEA Réel)"]
        end
        
        Parser["NMEA Parser<br/>(RMC, VWT, MWV, etc.)"]
        
        Provider["telemetryBusProvider<br/>(Sélection automatique)"]
        
        subgraph Streams ["Streams Riverpod"]
            Snapshot["snapshots()"]
            Watch["watch(key)"]
        end
        
        subgraph Consumers ["Consommateurs"]
            Wind["Wind Providers<br/>(windSampleProvider)"]
            Metrics["Metric Providers<br/>(metricProvider)"]
            Widgets["Widgets & Features<br/>(Charts, Alarms, etc.)"]
        end
    end

    Network -->|UDP Port 10110| NetworkBus
    NetworkBus --> Parser
    Parser -->|Measurements| NetworkBus
    
    Config --> Selection
    Selection -->|Mode fake| FakeBus
    Selection -->|Mode network| NetworkBus
    
    FakeBus --> Provider
    NetworkBus --> Provider
    
    Provider --> Snapshot
    Provider --> Watch
    
    Snapshot --> Wind
    Watch --> Metrics
    
    Wind --> Widgets
    Metrics --> Widgets
    
    style Miniplexe fill:#FF9800
    style Network fill:#2196F3
    style NetworkBus fill:#4CAF50
    style FakeBus fill:#9C27B0
    style Parser fill:#00BCD4
    style Widgets fill:#F44336
```

## Flux de Données NMEA

```mermaid
sequenceDiagram
    actor User as Utilisateur
    participant Config as Configuration<br/>NetworkConfigScreen
    participant Provider as Providers<br/>Riverpod
    participant Bus as NetworkTelemetryBus
    participant Parser as NmeaParser
    participant Miniplexe as Miniplexe 2Wi<br/>(UDP)
    participant App as Application UI

    User->>Config: Configure IP/Port
    Config->>Provider: setMode(network)
    Provider->>Bus: Create NetworkTelemetryBus
    Bus->>Miniplexe: UDP Bind & Listen
    
    Miniplexe->>Bus: $IIVWT,270.0,T,0.0,M,12.5,N,23.2,K*42
    Bus->>Parser: parse(sentence)
    Parser->>Parser: Extract wind.twd=270°<br/>Extract wind.tws=12.5kt
    Parser-->>Bus: NmeaSentenceResult
    
    Bus->>Bus: Create TelemetrySnapshot<br/>(metrics)
    Bus->>Provider: Emit snapshot via stream
    
    Provider->>App: windSampleProvider<br/>windSample.directionDeg=270<br/>windSample.speed=12.5
    
    App->>App: Rebuild UI with<br/>live NMEA data
    
    Note over Miniplexe: Autres sentences reçues...<br/>RMC, MWV, DPT, etc.
    
    loop Toutes les secondes
        Miniplexe->>Bus: UDP Datagrams
        Bus->>Parser: Parse NMEA
        Parser-->>Bus: Measurements
        Bus->>Provider: Emit
        Provider->>App: Update UI
    end
```

## Architecture de Parsing

```mermaid
graph LR
    Raw["UDP Datagram<br/>Raw bytes"]
    
    subgraph Parser ["NmeaParser.parse()"]
        Decode["1. Décode String"]
        Extract["2. Extrait Header<br/>(Talker + Sentence Type)"]
        Route["3. Route par Type<br/>(RMC, VWT, MWV, etc.)"]
        Parse["4. Parse Champs"]
        Unit["5. Convertit Unités"]
        Create["6. Crée Measurements"]
    end
    
    Result["NmeaSentenceResult<br/>with measurements"]
    
    Raw --> Decode
    Decode --> Extract
    Extract --> Route
    Route --> Parse
    Parse --> Unit
    Unit --> Create
    Create --> Result
    
    style Parser fill:#E3F2FD
```

## Sélection Automatique de Source

```mermaid
graph TD
    Start["telemetryBusProvider"]
    
    Check{"telemetrySourceMode<br/>== network?"}
    
    Check -->|OUI| CheckConfig{"networkConfig<br/>.enabled?"}
    Check -->|NON| UseFake["Utilise FakeTelemetryBus<br/>(Simulation)"]
    
    CheckConfig -->|OUI| TryCreate["Crée NetworkTelemetryBus"]
    CheckConfig -->|NON| UseFake
    
    TryCreate --> TryConnect["await bus.connect()"]
    TryConnect --> Success{"Connexion<br/>réussie?"}
    
    Success -->|OUI| UseNetwork["Utilise NetworkTelemetryBus<br/>(NMEA Réel) ✅"]
    Success -->|NON| Fallback["⚠️ Fallback sur<br/>FakeTelemetryBus<br/>(Mode Dégradé)"]
    
    UseNetwork --> Return["return TelemetryBus"]
    UseFake --> Return
    Fallback --> Return
    
    style UseNetwork fill:#4CAF50,color:#fff
    style UseFake fill:#9C27B0,color:#fff
    style Fallback fill:#FF9800,color:#fff
    style Return fill:#2196F3,color:#fff
```

## État de Connexion Réseau

```mermaid
stateDiagram-v2
    [*] --> Disconnected
    
    Disconnected --> Connecting: connect()
    
    Connecting --> Connected: ✅ UDP Ready
    Connecting --> Disconnected: ❌ Erreur
    
    Connected --> Receiving: Datagram reçu
    
    Receiving --> Parsing: Parse NMEA
    Parsing --> Emitting: Émet metrics
    Emitting --> Receiving
    
    Receiving --> ConnectionLost: UDP Error
    Connected --> ConnectionLost: UDP Close
    
    ConnectionLost --> Reconnecting: Auto-reconnect<br/>(5s delay)
    Reconnecting --> Connecting
    
    Disconnected --> [*]
    
    note right of Connected
        lastValidData = now()
        isConnected = true
    end note
    
    note right of Disconnected
        isConnected = false
        errorMessage = ?
    end note
```

## Intégration Transparente

```mermaid
graph TB
    subgraph "Avant NMEA (Simulation uniquement)"
        OldFake["FakeTelemetryBus"]
        OldWind["windSampleProvider"]
        OldApp["Application"]
        OldFake --> OldWind
        OldWind --> OldApp
    end
    
    subgraph "Après NMEA (Flexible)"
        NewSelect["Mode Selector<br/>(Fake vs Network)"]
        NewFake["FakeTelemetryBus"]
        NewNetwork["NetworkTelemetryBus"]
        NewBus["Unified TelemetryBus<br/>Interface"]
        NewWind["windSampleProvider<br/>(unchanged!)"]
        NewApp["Application<br/>(unchanged!)"]
        
        NewSelect --> NewFake
        NewSelect --> NewNetwork
        NewFake --> NewBus
        NewNetwork --> NewBus
        NewBus --> NewWind
        NewWind --> NewApp
    end
    
    style OldApp fill:#F44336,color:#fff
    style NewApp fill:#4CAF50,color:#fff
    style NewBus fill:#2196F3,color:#fff
```

## Cas d'Usage: Régate en Temps Réel

```mermaid
graph LR
    Start["⛵ Départ Régate"]
    
    Connect["Se connecter<br/>au WiFi du bateau"]
    Config["Configurer IP/Port<br/>du Miniplexe"]
    Test["Tester connexion<br/>(Badge vert ✅)"]
    
    Race["Navigation en Course"]
    
    NMEA["Données NMEA temps réel<br/>- Position GPS<br/>- Vent vrai (TWS/TWD)<br/>- Profondeur<br/>- Température eau"]
    
    Alarms["Alarmes Avancées<br/>- Profondeur min atteinte<br/>- Vent faible/fort"]
    Routing["Routage Optimisé<br/>- Polaires réelles<br/>- Calcul vitesse bateau"]
    Analysis["Analyse Tactique<br/>- Historique vent<br/>- Bascules (veering/backing)"]
    
    Connect --> Config
    Config --> Test
    Test --> Race
    
    Race --> NMEA
    NMEA --> Alarms
    NMEA --> Routing
    NMEA --> Analysis
    
    Alarms -.->|Alert| Race
    Routing -.->|Suggestion| Race
    Analysis -.->|Info| Race
    
    style Start fill:#FF9800,color:#fff
    style NMEA fill:#4CAF50,color:#fff
    style Race fill:#2196F3,color:#fff
    style Alarms fill:#F44336,color:#fff
```

---

**Voir aussi:** `NMEA_INTEGRATION_GUIDE.md` pour documentation textuelle complète.
