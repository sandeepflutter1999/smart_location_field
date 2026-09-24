
## 0.3.1

- Shortened the pubspec description to fit pub.dev's 60–180 character guideline.

## 0.3.0

- Added demo screenshots and GIFs (`screenshots/`) to README and pub.dev.
- Bumped to `smart_api: ^1.1.1`. Calls now use `SmartApiClient.instance.get`
  (the old wiring pointed at a class/method that doesn't exist, which was
  the compile error).
- New `LocationSearchLevel.location` — normal, unrestricted location search
  (addresses, areas, landmarks, businesses). Selected text stays exactly as
  the tapped suggestion.

## 0.2.0

- Switched networking from raw `http`/https calls to `smart_api: ^1.0.5`.
  All Google Places calls now go through one `_defaultSmartApiGet()`
  function — check its assumption about `SmartApi.get(url)` against your
  actual package, and adjust that one function if needed.
- Every icon slot (prefix, suffix, password toggle, suggestion row icon) is
  now icon-or-image, per instance: `prefixIcon`/`prefixImagePath`,
  `suffixIcon`/`suffixImagePath`, `obscureIcon`/`obscureImagePath`,
  `unObscureIcon`/`unObscureImagePath`, `suggestionIcon`/`suggestionImagePath`.
- Validator is now explicitly either/or: pass `validator` for full custom
  logic, or just `validatorText` for a simple required-field message
  (defaults to "This field is required" if neither is given).

## 0.1.0

- Initial release.
- `SmartLocationField` widget: normal TextFormField mode (with optional
  password obscure/eye-icon support) plus Google Places search mode.
- `LocationSearchLevel.country` / `.state` / `.city` to restrict
  autocomplete results to one granularity.
- `restrictToCountries` to scope state/city search to specific countries.
- `lat` / `lng` bias support.
- Debounced input (`debounceDuration`, `minSearchLength`).
- Pluggable `apiCaller` so Google Places calls can be routed through your
  own network/API layer instead of calling `http` directly.
