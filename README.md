# Baufismart Kundenangaben Angebote Mapping

Tools and helper scripts for working with the BaufiSmart Kundenangaben API and Angebote API.

📖 See:
[baufismart-kundenangaben-api](https://github.com/europace/baufismart-kundenangaben-api)
and [baufismart-angebote-api](https://github.com/europace/baufismart-angebote-api)


## 🛠️ Helper Scripts

### 📋 `list-kundenangaben-field-types.sh`

Downloads the Kundenangaben OpenAPI spec and prints every leaf field path with its type.

#### ▶️ Usage

```bash
# Download the latest spec and print all fields
./list-kundenangaben-field-types.sh

# Use a local spec file instead of downloading
./list-kundenangaben-field-types.sh path/to/kundenangaben-openapi.json
```

#### 📄 Output format

Each line is `<path>=<type>`:

```
importMetadaten.betreuung.bearbeiter=string
importMetadaten.datenkontext=enum(TEST_MODUS, ECHT_GESCHAEFT)
kundenangaben.haushalte[].kunden[].wohnsituation.voranschrift.ort=string
kundenangaben.finanzierungsbedarf.externeBausparangebote[].bausparkasse=enum(AACHENER_BAUSPARKASSE, ...)
```

| Symbol | Meaning |
|--------|---------|
| `[]` | Array items |
| `enum(...)` | Enumeration with all allowed values |
| `(discriminator)` | Polymorphic type discriminator field |
| `(cycle)` | Recursive reference that was cut off |

The spec is downloaded from the [baufismart-kundenangaben-api](https://github.com/europace/baufismart-kundenangaben-api) repository and cached locally as `kundenangaben.json`.

#### ⚙️ Requirements

🐍 Python 3 (stdlib only, no dependencies).
