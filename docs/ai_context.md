# AI Context: Р‘РёРѕРЎР±РѕСЂРєР°

## Р‘Р°Р·РѕРІР°СЏ Р°СЂС…РёС‚РµРєС‚СѓСЂР°
- Backend РїРѕР»РЅРѕСЃС‚СЊСЋ СЂРµР°Р»РёР·РѕРІР°РЅ РІ Oracle PL/SQL.
- Р¦РµРЅС‚СЂР°Р»СЊРЅС‹Р№ backend API: `pkg_genetics_game`.
- Python вЂ” С‚РѕР»СЊРєРѕ GUI-РєР»РёРµРЅС‚ (РїРѕРґРєР»СЋС‡РµРЅРёРµ Рє Oracle, РІС‹Р·РѕРІ package API, РѕС‚РѕР±СЂР°Р¶РµРЅРёРµ РґР°РЅРЅС‹С…).
- Python РЅРµ РїРµСЂРµРЅРѕСЃРёС‚ Рё РЅРµ РґСѓР±Р»РёСЂСѓРµС‚ backend-Р±РёР·РЅРµСЃ-Р»РѕРіРёРєСѓ.
- GUI РЅРµ РёСЃРїРѕР»СЊР·СѓРµС‚ `dbms_output`.

## РўРµРєСѓС‰РёР№ РїРѕРґС‚РІРµСЂР¶РґС‘РЅРЅС‹Р№ СЃС‚Р°С‚СѓСЃ (2026-05-27)

### Backend strict-pass
- `pkg_genetics_game` spec/body РєРѕРјРїРёР»РёСЂСѓСЋС‚СЃСЏ.
- `user_errors` РїСѓСЃС‚РѕР№.
- Smoke-tests `01..08` РїСЂРѕС€Р»Рё Р·РµР»С‘РЅС‹Рј (`Failed: 0`).

### Content compliance pass
РС‚РѕРіРѕРІС‹Рµ РѕР±СЉС‘РјС‹ seed:
- genes: 12
- alleles: 24
- mutations: 12
- mutation_rules: 12
- tasks: 12
- task_markers: 21

РџРѕРєСЂС‹С‚РёРµ:
- СѓРЅРёРІРµСЂСЃР°Р»СЊРЅС‹Рµ РїСЂРёР·РЅР°РєРё;
- `species_type 1..6` РїРѕ mutation_rules Рё task_markers.

### Economy pass
- `buy_mutation`: СЃРїРёСЃС‹РІР°РµС‚ wallet, СѓРІРµР»РёС‡РёРІР°РµС‚ stock, rating РЅРµ РјРµРЅСЏРµС‚.
- `apply_mutation`: РїСЂРёРјРµРЅСЏРµС‚ mutation_rules, СѓРјРµРЅСЊС€Р°РµС‚ stock, СЃРѕР·РґР°С‘С‚ MUTATION experiment, РїСЂРёРјРµРЅСЏРµС‚ `rating_effect` С‡РµСЂРµР· `greatest(0, ...)`, Р·Р°С‚РµРј auto-complete tasks.
- `apply_mutagen`: СЃРѕР·РґР°С‘С‚ РјСѓС‚Р°РЅС‚Р° + MUTAGEN experiment + auto-complete tasks.
  - RADIATION: cost 50, rating_delta -5.
  - CHEMICAL: cost 100, rating_delta -2.
- Р РµР№С‚РёРЅРі РЅРµ СѓС…РѕРґРёС‚ РЅРёР¶Рµ 0.
- Р РѕСЃС‚ СЂРµР№С‚РёРЅРіР° РїРѕСЃР»Рµ РјСѓС‚Р°РіРµРЅР° РІРѕР·РјРѕР¶РµРЅ Р·Р° СЃС‡С‘С‚ task rewards.

### Multiuser strict-pass
- Session-bound РјРѕРґРµР»СЊ РґРѕСЃС‚СѓРїР° Рє Р»Р°Р±РѕСЂР°С‚РѕСЂРёРё.
- Р”РѕР±Р°РІР»РµРЅ `g_current_lab_id`.
- `load_lab/switch_lab` РёСЃРїРѕР»СЊР·СѓСЋС‚ `FOR UPDATE`, РїСЂРѕРІРµСЂСЏСЋС‚ owner Рё Р·Р°РЅСЏС‚РѕСЃС‚СЊ lab.
- РћС€РёР±РєРё:
  - `-20072` lab already opened in another active session;
  - `-20073` selected lab is not active in current session.
- `assert_lab_access`/`assert_creature_access` РїСЂРѕРІРµСЂСЏСЋС‚ owner + Р°РєС‚РёРІРЅСѓСЋ lab РІ С‚РµРєСѓС‰РµР№ session.
- Р”РѕР±Р°РІР»РµРЅ `08_multiuser_sessions_smoke_test.sql`.

### GUI СЂРµР°Р»РёР·РѕРІР°РЅ
- Auth
- Lab Selection
- Main Shell
- РЎСѓС‰РµСЃС‚РІР°
- Р“РµРЅРµС‚РёС‡РµСЃРєРёР№ СЌРєСЃРїРµСЂРёРјРµРЅС‚
- РњСѓС‚Р°С†РёРё
- Р—Р°РґР°РЅРёСЏ
- РСЃС‚РѕСЂРёСЏ СЌРєСЃРїРµСЂРёРјРµРЅС‚РѕРІ

### Display localization
- РСЃРїРѕР»СЊР·СѓРµС‚СЃСЏ `python_client/app/services/display_names.py`.
- Р СѓСЃРёС„РёС†РёСЂРѕРІР°РЅРѕ РѕС‚РѕР±СЂР°Р¶РµРЅРёРµ РІРёРґРѕРІ, РіРµРЅРѕРІ, Р°Р»Р»РµР»РµР№, dominance/status/experiment/mutagen С‚РёРїРѕРІ, РЅР°Р·РІР°РЅРёР№ Р·Р°РґР°С‡/РјСѓС‚Р°С†РёР№, phenotype summary.
- Р­С‚Рѕ display-layer, РЅРµ Р±РёР·РЅРµСЃ-Р»РѕРіРёРєР°.

### Р—Р°РєСЂС‹С‚С‹Р№ РёРЅС†РёРґРµРЅС‚
- Р‘С‹Р»Р° СЃР»РѕРјР°РЅР° РєРѕРґРёСЂРѕРІРєР° РІРѕ РІРєР»Р°РґРєРµ В«Р—Р°РґР°РЅРёСЏВ» (mojibake/`????`).
- РСЃРїСЂР°РІР»РµРЅРѕ Р±РµР· backend-РёР·РјРµРЅРµРЅРёР№:
  - `python_client/app/services/display_names.py`
  - `python_client/app/gui/tasks_tab.py`
- РџСЂРѕРІРµСЂРєРё:
  - `python -m compileall -f python_client` СѓСЃРїРµС€РЅРѕ;
  - `display_task_name` РІРѕР·РІСЂР°С‰Р°РµС‚ РєРѕСЂСЂРµРєС‚РЅС‹Рµ СЂСѓСЃСЃРєРёРµ Р·РЅР°С‡РµРЅРёСЏ.

## Р’Р°Р¶РЅС‹Рµ РїСЂР°РІРёР»Р° РґР»СЏ СЃР»РµРґСѓСЋС‰РёС… СЃРµСЃСЃРёР№
- UI/РїРѕРґСЃРєР°Р·РєРё/РёРіСЂРѕРІС‹Рµ С„РѕСЂРјСѓР»РёСЂРѕРІРєРё вЂ” РЅР° СЂСѓСЃСЃРєРѕРј.
- РђРЅРіР»РёР№СЃРєРёР№ РѕСЃС‚Р°РІР»СЏС‚СЊ С‚РѕР»СЊРєРѕ РґР»СЏ С‚РµС…РЅРёС‡РµСЃРєРёС… РёРјС‘РЅ/API/enum/РїРѕР»РµР№ Р‘Р”.
- Python РЅРµ СЃС‡РёС‚Р°РµС‚ РіРµРЅРµС‚РёРєСѓ, РјСѓС‚Р°С†РёРё, СЌРєРѕРЅРѕРјРёРєСѓ, Р·Р°РґР°РЅРёСЏ, СЂРµР№С‚РёРЅРі, СЃС‚Р°С‚РёСЃС‚РёРєСѓ.
- Р’СЃРµ С‚Р°РєРёРµ СЂР°СЃС‡С‘С‚С‹ РІС‹РїРѕР»РЅСЏРµС‚ С‚РѕР»СЊРєРѕ PL/SQL backend.
- Python-С„Р°Р№Р»С‹ СЃ РєРёСЂРёР»Р»РёС†РµР№ С…СЂР°РЅРёС‚СЊ РІ UTF-8.

## РџРѕСЃР»РµРґРЅРёРµ Р·Р°РєСЂС‹С‚С‹Рµ GUI-РёРЅС„СЂР°СЃС‚СЂСѓРєС‚СѓСЂРЅС‹Рµ РїСѓРЅРєС‚С‹
- CloseEvent/logout fix РІС‹РїРѕР»РЅРµРЅ: Р·Р°РєСЂС‹С‚РёРµ С‡РµСЂРµР· `X` РІС‹Р·С‹РІР°РµС‚ logout flow, РѕС‡РёС‰Р°РµС‚ session state Рё Р·Р°РєСЂС‹РІР°РµС‚ Oracle connection.
- `oracle_errors.py` СЃРѕРґРµСЂР¶РёС‚ СЂСѓСЃСЃРєРёРµ СЃРѕРѕР±С‰РµРЅРёСЏ РґР»СЏ `ORA-20072` Рё `ORA-20073`.
- Р”РѕР±Р°РІР»РµРЅ dev-only СЃРєСЂРёРїС‚ РІРѕСЃСЃС‚Р°РЅРѕРІР»РµРЅРёСЏ СЃС‚Р°СЂС‹С… Р·Р°РІРёСЃС€РёС… sessions: `database/scripts/dev_unlock_stale_sessions.sql`.
- РСЃС‚РѕСЂРёСЏ СЌРєСЃРїРµСЂРёРјРµРЅС‚РѕРІ РїРѕР»СѓС‡Р°РµС‚ СЂРµР°Р»СЊРЅС‹Р№ `experiments.created_at`.

## РђСѓРґРёС‚ СЂР°СЃС€РёСЂРµРЅРёСЏ РїСЂРёР·РЅР°РєРѕРІ/РєРѕРЅС‚РµРЅС‚Р° (Р›Р 1/Р›Р 2/KB)
Р’С‹РІРѕРґ: С‚РµРєСѓС‰РёР№ РєР°С‚Р°Р»РѕРі РґРѕСЃС‚Р°С‚РѕС‡РµРЅ РґР»СЏ baseline Р›Р 1/Р›Р 2, РЅРѕ С‡Р°СЃС‚РёС‡РЅРѕ С‚СЂРµР±СѓРµС‚ С‚РѕС‡РµС‡РЅРѕРіРѕ СЂР°СЃС€РёСЂРµРЅРёСЏ, РµСЃР»Рё РЅСѓР¶РЅР° Р±РѕР»РµРµ РїРѕР»РЅР°СЏ РґРµРјРѕРЅСЃС‚СЂР°С†РёСЏ KB.

РўРµРєСѓС‰РёР№ seed:
- `genes=12`
- `alleles=24`
- `mutations=12`
- `mutation_rules=12`
- `tasks=12`
- `task_markers=21`

РџРѕРєСЂС‹С‚РёРµ:
- 6 РІРёРґРѕРІ СЃСѓС‰РµСЃС‚РІ: С…СЂСЏС‰РµРІС‹Рµ СЂС‹Р±С‹, РєРѕСЃС‚РЅС‹Рµ СЂС‹Р±С‹, СЂР°РєРѕРѕР±СЂР°Р·РЅС‹Рµ, РјРѕР»Р»СЋСЃРєРё, С‡РµСЂРµРїР°С…Рё, РјР»РµРєРѕРїРёС‚Р°СЋС‰РёРµ.
- РЈРЅРёРІРµСЂСЃР°Р»СЊРЅС‹Рµ РїСЂРёР·РЅР°РєРё: `color`, `size`, `nutrition_type`, `has_wings`.
- Р’РёРґРѕСЃРїРµС†РёС„РёС‡РЅС‹Рµ РїСЂРёР·РЅР°РєРё РµСЃС‚СЊ РґР»СЏ `species_type 1..6`.
- `FULL`, `INCOMPLETE`, `CODOMINANT` СЂРµР°Р»РёР·РѕРІР°РЅС‹.
- `mutation_rules` Рё `task_markers` РїРѕРєСЂС‹РІР°СЋС‚ СѓРЅРёРІРµСЂСЃР°Р»СЊРЅС‹Рµ РїСЂРёР·РЅР°РєРё Рё РІСЃРµ `species_type 1..6`.

Р РµРєРѕРјРµРЅРґР°С†РёРё:
- РќРµ РґРѕР±Р°РІР»СЏС‚СЊ РЅРѕРІС‹Рµ РіРµРЅС‹/Р°Р»Р»РµР»Рё Р±РµР· РїРѕРґС‚РІРµСЂР¶РґС‘РЅРЅРѕР№ KB-СЃС‚СЂРѕРєРё.
- Р•СЃР»Рё СЂР°СЃС€РёСЂСЏС‚СЊ, РЅР°С‡РёРЅР°С‚СЊ СЃ seed-only pass + tests `02`/`07` + `display_names.py`.
- РЈСЃРёР»РёС‚СЊ linkage С‚РѕР»СЊРєРѕ РѕСЃРјС‹СЃР»РµРЅРЅС‹РјРё РїР°СЂР°РјРё РіРµРЅРѕРІ; СЃРµР№С‡Р°СЃ СЃРІСЏР·Р°РЅРЅР°СЏ РїР°СЂР° СЏРІРЅРѕ РґРµРјРѕРЅСЃС‚СЂРёСЂСѓРµС‚СЃСЏ Сѓ С‡РµСЂРµРїР°С…, Р° СЂС‹Р±РЅС‹Рµ linkage-РіСЂСѓРїРїС‹ РјРµРЅРµРµ РїРѕРєР°Р·Р°С‚РµР»СЊРЅС‹.
- РўРёРї РјСѓС‚Р°РіРµРЅР°/РёР·РјРµРЅС‘РЅРЅС‹Р№ РіРµРЅ РІ РёСЃС‚РѕСЂРёРё Рё `creatures.generation` вЂ” РѕС‚РґРµР»СЊРЅС‹Рµ backend/DDL-С‚СЂРµРєРё, РЅРµ seed-only.

## Pending next
- Р•СЃР»Рё РїРѕР»СЊР·РѕРІР°С‚РµР»СЊ РїРѕРґС‚РІРµСЂРґРёС‚ СЂР°СЃС€РёСЂРµРЅРёРµ РєРѕРЅС‚РµРЅС‚Р°, РїРѕРґРіРѕС‚РѕРІРёС‚СЊ РѕС‚РґРµР»СЊРЅС‹Р№ РїР»Р°РЅ seed/test/display РёР·РјРµРЅРµРЅРёР№.
- Р‘РµР· РїРѕРґС‚РІРµСЂР¶РґРµРЅРёСЏ РЅРµ РјРµРЅСЏС‚СЊ seed, package, DDL, Python GUI Рё smoke-tests.

## Content/GUI pass: С„РѕСЂРјСѓР»РёСЂРѕРІРєРё Р·Р°РґР°РЅРёР№ (РѕР±РЅРѕРІР»РµРЅРѕ)
- Р’ seed РѕР±РЅРѕРІР»РµРЅС‹ С‚РѕР»СЊРєРѕ С‚РµРєСЃС‚С‹ tasks.description РґР»СЏ СѓСЃС‚СЂР°РЅРµРЅРёСЏ РґРІСѓСЃРјС‹СЃР»РµРЅРЅРѕСЃС‚Рё UX.
- РџСЂРѕСЃС‚С‹Рµ Р·Р°РґР°С‡Рё С„РѕСЂРјСѓР»РёСЂСѓСЋС‚СЃСЏ РєР°Рє find/tutorial (РќР°Р№РґРёС‚Рµ / РћС‚Р±РµСЂРёС‚Рµ / РїСЂРµРґСЉСЏРІРёС‚Рµ).
- Backend РЅРµ РёР·РјРµРЅСЏР»СЃСЏ: check_task РїСЂРѕРІРµСЂСЏРµС‚ РїСЂРёР·РЅР°РєРё СЃСѓС‰РµСЃС‚РІР°, Р° РЅРµ РµРіРѕ РїСЂРѕРёСЃС…РѕР¶РґРµРЅРёРµ.
- Р Р°Р·РґРµР»РµРЅРёРµ С‚РёРїРѕРІ Р·Р°РґР°С‡ FIND/BREED/MUTATE РѕСЃС‚Р°С‘С‚СЃСЏ РѕС‚РґРµР»СЊРЅС‹Рј DDL/backend-С‚СЂРµРєРѕРј.



## Update: UX polish stage 1
- Р”РѕР±Р°РІР»РµРЅС‹ onboarding-РїРѕРґСЃРєР°Р·РєРё Рё empty-state СЃРѕСЃС‚РѕСЏРЅРёСЏ РІ РєР»СЋС‡РµРІС‹С… РѕРєРЅР°С… GUI.
- Backend/DDL/spec/body/seed/tests РЅРµ РјРµРЅСЏР»РёСЃСЊ.
- Python РѕСЃС‚Р°С‘С‚СЃСЏ С‚РѕР»СЊРєРѕ РєР»РёРµРЅС‚РѕРј РѕС‚РѕР±СЂР°Р¶РµРЅРёСЏ Рё РІС‹Р·РѕРІР° PL/SQL API.
- РљРѕРјРїРёР»СЏС†РёСЏ РєР»РёРµРЅС‚Р° РїРѕРґС‚РІРµСЂР¶РґРµРЅР°: python -m compileall -f python_client.

## Update: mutation-rules coherence
- РљРѕСЂРµРЅСЊ РёРЅС†РёРґРµРЅС‚Р° ORA-20045: apply_mutation РїСЂРёРјРµРЅСЏРµС‚ РІСЃРµ rules РјСѓС‚Р°С†РёРё.
- РЎРјРµС€Р°РЅРЅС‹Рµ РјСѓС‚Р°С†РёРё СЂР°Р·РґРµР»РµРЅС‹ РІ seed РЅР° РІРёРґРѕСЃРїРµС†РёС„РёС‡РЅС‹Рµ; GUI display-СЃР»РѕР№ РїРѕР»СѓС‡РёР» РЅР°Р·РІР°РЅРёСЏ РЅРѕРІС‹С… mutation_name.

## Update: GUI polish stage 2 checkpoint
- Р¤РёРЅР°Р»СЊРЅС‹Р№ GUI polish Р­С‚Р°Рї 2 РЅР°С‡Р°С‚: СЂР°Р·РіСЂСѓР·РєР° С‚Р°Р±Р»РёС† В«РЎСѓС‰РµСЃС‚РІР°В», В«Р—Р°РґР°РЅРёСЏВ», В«РСЃС‚РѕСЂРёСЏ СЌРєСЃРїРµСЂРёРјРµРЅС‚РѕРІВ».
- РР·РјРµРЅРµРЅРёСЏ Р­С‚Р°РїР° 2 Р·Р°С‚СЂР°РіРёРІР°СЋС‚ С‚РѕР»СЊРєРѕ Python GUI: `creatures_tab.py`, `tasks_tab.py`, `history_tab.py`; С‚Р°РєР¶Рµ СѓР¶Рµ Р±С‹Р» РґРѕР±Р°РІР»РµРЅ Р°РІР°СЂРёР№РЅС‹Р№ cleanup РїСЂРё РѕС€РёР±РєРµ РѕС‚РєСЂС‹С‚РёСЏ `MainWindow` РІ `app.py`.
- Р¦РµР»СЊ Р­С‚Р°РїР° 2: СѓР±СЂР°С‚СЊ РґР»РёРЅРЅС‹Рµ/С‚РµС…РЅРёС‡РµСЃРєРёРµ РєРѕР»РѕРЅРєРё РёР· РѕСЃРЅРѕРІРЅРѕРіРѕ С„РѕРєСѓСЃР°, РѕСЃС‚Р°РІРёС‚СЊ РґРµС‚Р°Р»Рё РІ РєР°СЂС‚РѕС‡РєР°С… Рё tooltip, РЅРµ РјРµРЅСЏСЏ backend.
- РљРѕРЅС‚СЂРѕР»СЊРЅР°СЏ С‚РѕС‡РєР° РїРµСЂРµРґ РєРѕРјРјРёС‚РѕРј: GUI РґРѕР»Р¶РµРЅ РѕС‚РєСЂС‹РІР°С‚СЊ СЃСѓС‰РµСЃС‚РІСѓСЋС‰СѓСЋ Рё РЅРѕРІСѓСЋ Р»Р°Р±РѕСЂР°С‚РѕСЂРёСЋ Р±РµР· РѕС€РёР±РѕРє `QHeaderView`.
- РћС€РёР±РєРё, СЃРІСЏР·Р°РЅРЅС‹Рµ СЃ СЌС‚Р°РїРѕРј: СЃС‚Р°СЂС‹Р№ enum-СЃС‚РёР»СЊ `QHeaderView.Stretch` Рё РѕС‚СЃСѓС‚СЃС‚РІРёРµ РёРјРїРѕСЂС‚Р° `QHeaderView` РїСЂРё РёСЃРїРѕР»СЊР·РѕРІР°РЅРёРё `QHeaderView.ResizeMode.*`.
- РЎР»РµРґСѓСЋС‰Р°СЏ СЃРµСЃСЃРёСЏ РґРѕР»Р¶РЅР° РЅР°С‡Р°С‚СЊ СЃ `git status`, `python -m compileall -f python_client`, РїСЂРѕРІРµСЂРєРё РёРјРїРѕСЂС‚РѕРІ `QHeaderView` Рё СЂСѓС‡РЅРѕРіРѕ РѕС‚РєСЂС‹С‚РёСЏ РІРєР»Р°РґРѕРє В«РЎСѓС‰РµСЃС‚РІР°В», В«Р—Р°РґР°РЅРёСЏВ», В«РСЃС‚РѕСЂРёСЏ СЌРєСЃРїРµСЂРёРјРµРЅС‚РѕРІВ».
- Р­С‚Р°Рї 2 РЅРµ РєРѕРјРјРёС‚РёС‚СЊ, РїРѕРєР° СЂСѓС‡РЅР°СЏ РїСЂРѕРІРµСЂРєР° GUI РЅРµ РїРѕРґС‚РІРµСЂРґРёС‚ РѕС‚РєСЂС‹С‚РёРµ Р»Р°Р±РѕСЂР°С‚РѕСЂРёРё Рё РѕС‚СЃСѓС‚СЃС‚РІРёРµ `ORA-20072` РїРѕСЃР»Рµ Р·Р°РєСЂС‹С‚РёСЏ С‡РµСЂРµР· `X`.

<!-- biosborka-checkpoint-2026-06-02:start -->
## Контрольная точка: стабилизация после graphics/content-pass

Актуальный workspace: `C:\GameLR3`. Старый путь `C:\Users\User\DATA\Моя учеба\GameLR3` не использовать.

Текущий статус:
- Backend/content/economy/multiuser/history в целом закрыты.
- Backend остаётся полностью в Oracle PL/SQL, центральный API — `pkg_genetics_game`.
- Python остаётся только GUI/display-layer и не считает генетику, мутации, задания, экономику или рейтинг.
- Oracle smoke-tests `01..08` до последних GUI/content-pass были зелёными.
- `python -m compileall -f python_client` после ручного исправления портретов и mojibake проходит.
- GUI-стиль: бумажно-рисованный, тетрадный, вдохновлённый ощущением «Алхимии на бумаге», без копирования ассетов/интерфейса/визуальных элементов 1-в-1.

Закрытые важные этапы:
- Multiuser strict-pass: `g_current_lab_id`, session-bound lab access, ошибки `-20072` и `-20073`, dev-only script `database/scripts/dev_unlock_stale_sessions.sql`.
- GUI session handling: «К лабораториям» без logout, «Выйти из аккаунта» с `logout_user`, закрытие через X должно завершать session, авария открытия MainWindow безопасно закрывает session.
- Mixed `mutation_rules` разделены: `aquatic_form_mutation` species 1, `aquatic_form_bony_mutation` species 2, `aquatic_form_turtle_shell_mutation` species 5, `morphology_refine_mutation` species 3, `morphology_refine_mollusk_mutation` species 4, `morphology_refine_mammal_mutation` species 6.
- `get_experiment_history` отдаёт `e.created_at`.
- Задания проверяются по `task_markers`; происхождение существа не проверяется, поэтому формулировки должны быть честными: «найдите/отберите/предъявите» и конкретными по признакам.

Аварийная история после graphics/content-polish:
- GUI падал при открытии лаборатории: `CreaturePortraitWidget.set_creature() takes 7 positional arguments but 8 were given`.
- Причина: рассинхрон `set_creature(...)` и вызовов с `creature_key`.
- Ручной fix уже применён: `set_creature(..., creature_key=None)`, `clear()` вызывает `self.set_creature()`, `_variant_seed` инициализирован, placeholder `display_value` удалён.
- После этого GUI стал открываться.
- Затем частично сломалась кодировка в `creatures_tab.py`, `crossbreed_tab.py`, `mutations_tab.py`; выполнен hard-fix mojibake, `compileall` проходит.

Блокеры перед продолжением roadmap:
- Во вкладке «Мутации» колонка «Описание» магазина мутаций всё ещё может показывать mojibake. Проверить seed и БД: `select mutation_id, mutation_name, description from mutations order by mutation_id;`.
- Удалить backup-файлы `*.bak_mojibake` и `*.bak_mojibake2` перед коммитом.
- Стабилизировать `database/tests/05_mutations_experiments_smoke_test.sql`: проверка RADIATION wallet должна учитывать auto-complete rewards.
- Не продолжать Dashboard/graphics roadmap, пока не закрыты mojibake в «Мутациях», backup files, стабильный `05`, GUI-check без mojibake и Oracle `01..08` или минимум подтверждённые `02/05/06/07/08` после seed/test правок.
<!-- biosborka-checkpoint-2026-06-02:end -->

<!-- biosborka-creature-art-checkpoint-2026-06-06:start -->

## Creature Display / Creature Art checkpoint, 2026-06-06

Workspace: `C:\GameLR3`. Do not use the old `C:\Users\User\DATA\...` path.

Current phase: Creature Display / Creature Art polish. This phase is GUI/display-layer only.

Current status:
- `python_client/app/gui/creature_portrait.py` has display-only portrait improvements in progress.
- Emergency UTF-8 fix for new `creature_portrait.py` strings is complete.
- `python -m compileall -f python_client` passes.
- Marker-check over `python_client/app/gui/*.py` is clean for broken UTF-8 markers.
- Backend, DDL, package spec/body, seed, tests, and `pkg_api.py` were not changed.

First Creature Art block is implemented: shared portraits were improved and the Creatures tab now has a passport-style card. Manual GUI confirmation is still pending before final acceptance polish.

Next after confirmation:
- manually check portraits in Creatures, Crossbreed, Mutations, and Tasks;
- fix any visual/layout regressions if found;
- then move to final acceptance polish.

<!-- biosborka-creature-art-checkpoint-2026-06-06:end -->
