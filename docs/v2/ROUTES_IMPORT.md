# Pokatuha V2 — Routes Import

Status: APPROVED
Depends on: ARCHITECTURE_V2.md

---

## 1. Supported formats

- GPX (.gpx)
- FIT (.fit)
- KML (.kml)

---

## 2. Import flow

1. User taps «+» or route attachment
2. `file_picker` opens
3. Validate file extension and basic structure
4. Show map preview with polyline
5. Attach to activity

---

## 3. Sharing rules

- Route is NOT auto-copied to all participants
- Each participant downloads manually
- Route card in chat shows: mini map, distance, elevation, duration
- Buttons: «Открыть», «Скачать»

---

## 4. Storage

- Original file: local only (Sembast / filesystem)
- Optional: simplify polyline for lightweight preview
- Route data is part of activity local storage

---

## 5. External handoff

- «Открыть в навигаторе» — system intent to external maps app
- System share sheet for GPX/FIT/KML files
