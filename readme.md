
# AS24 Application Resource Usage Monitor

## Motivation
Alle AS24 Applikationen laufen in einer komplett virtualisierten Umgebung (aka AS24 Cloud) und teilen sich die
verfügbaren Resource, wie CPU, RAM, Network und Disk IO. Lokale Festplatten sind eine Illusion, alle Festplatten sind
virtuell und liegen auf einem zentralen (ausfallsicheren?, hochverfügbaren?) Storage.

1. Die Entwickler Teams haben keine Transparenz über die Anzahl und Konfiguration (CPU, RAM, DISK) der Server auf denen
   ihre (Legacy) Applikationen laufen.
   (Grund: In der Vergangenheit hat der Betrieb Server nach eigenem Ermessen provisioniert und betankt)

2. Das Cloud Team sieht eine flache Liste von über 2000 VMs und tut sich schwer eine VM Applikationen und Teams
   zuzuordnen. Das Finden und Löschen von alten, nicht mehr benutzten Servern ist schwierig.

3. VMWare Tools wie VCOps liefern falsche Signale über die Auslastung von Resourcen da sie unsere Systemarchitektur
   (Brandabschnitte, WebServer, JobServer, Testumgebungen) nicht kennen und berücksichtigen.
   Z.B. sind unsere Testsystem grundsätzlich nie ausgelastet, da sie nur im Testfall aktiv werden. Trotzdem müssen sie
   in einer produktions-nahen Konfiguration existieren (2 VMs mit je 2 CPUs) um produktions nah testen zu können.

## AS24 VM Dashboard


Das VM Dashboard ist eine kleine Hilfe um

Zielgruppe: Devs und Ops die sich mit VMs beschäftigen

![](http://s.autoscout24.net/favicon.png)

