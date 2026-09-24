# smart_location_field

A single Flutter `TextFormField` that can behave two ways:

1. **Normal field** — email, password (with a show/hide toggle), or any
   plain input.
2. **Google Places search field** — restrictable to **country-only**,
   **state-only**, **city-only**, or normal **location** search results,
   with a suggestions dropdown.

Every Google Places network call goes through `smart_api` (not raw
`http`/`https`) via one function, so swapping the exact call is a one-place
edit if needed. Every icon slot (prefix, suffix, the password toggle, the
suggestion row icon) can independently be an **icon or an image** — your
choice, per field, per slot.

## Demo

### Location search
<p align="center">
  <img src="https://raw.githubusercontent.com/sandeepflutter1999/smart_location_field/main/screenshots/location_search.gif" width="300" alt="Location search demo" />
  <img src="https://raw.githubusercontent.com/sandeepflutter1999/smart_location_field/main/screenshots/location.png" width="300" alt="Location search suggestions" />
</p>

### Validation (email / password)
<p align="center">
  <img src="https://raw.githubusercontent.com/sandeepflutter1999/smart_location_field/main/screenshots/validation.gif" width="300" alt="Validation demo" />
  <img src="https://raw.githubusercontent.com/sandeepflutter1999/smart_location_field/main/screenshots/email_password.png" width="300" alt="Email and password field" />
</p>

### Outlined style
<p align="center">
  <img src="https://raw.githubusercontent.com/sandeepflutter1999/smart_location_field/main/screenshots/style_outlined.gif" width="300" alt="Outlined style demo" />
  <img src="https://raw.githubusercontent.com/sandeepflutter1999/smart_location_field/main/screenshots/style_outlined.png" width="300" alt="Outlined style field" />
</p>

## Install

Add it as a path or git dependency in your app's `pubspec.yaml`:

```yaml
dependencies:
  smart_location_field:
    path: ../smart_location_field   # or a git/pub.dev reference once published
```

Then:

```dart
import 'package:smart_location_field/smart_location_field.dart';
```

## About the `smart_api` wiring

This package depends on `smart_api: ^1.1.1` and calls it from one place:
`_defaultSmartApiGet()` in `lib/src/smart_location_field_widget.dart`, using
`SmartApiClient.instance.get(...)`. Nothing uses raw `http`.

If you ever need a different call for one field, pass `apiCaller`:

```dart
SmartLocationField(
  ...
  apiCaller: (url) async {
    final res = await SmartApiClient.instance.get(url);
    return res.data as Map<String, dynamic>?;
  },
),
```

## Icon or image — your choice, per slot

Every affix has an icon param and an image-path param; the image wins if
both are set. A path starting with `http://`/`https://` loads as a network
image, anything else as an asset.

| Slot | Icon param | Image param |
|---|---|---|
| Prefix | `prefixIcon` | `prefixImagePath` |
| Suffix (non-password) | `suffixIcon` | `suffixImagePath` |
| Password toggle — hidden state | `obscureIcon` | `obscureImagePath` |
| Password toggle — visible state | `unObscureIcon` | `unObscureImagePath` |
| Suggestion row leading icon | `suggestionIcon` | `suggestionImagePath` |

```dart
// icon
SmartLocationField(
  prefixIcon: Icons.email_outlined,
  ...
),

// image instead — asset or network, same param
SmartLocationField(
  prefixImagePath: 'assets/icons/email.png',
  // or: prefixImagePath: 'https://example.com/email.png',
  ...
),
```

## Validator — your choice

- Pass a full custom function via `validator` and it's used exactly as
  given (your logic wins).
- Or just pass a message via `validatorText` and a built-in "required"
  check uses it as the error text.
- If `isValidator: true` and neither is given, it falls back to
  `"This field is required"`.

```dart
// just a message
SmartLocationField(
  isValidator: true,
  validatorText: "Email is required",
  ...
),

// full custom logic
SmartLocationField(
  isValidator: true,
  validator: (value) {
    if (value == null || value.isEmpty) return "Email is required";
    if (!value.contains('@')) return "Enter a valid email";
    return null;
  },
  ...
),
```

## Usage

### Plain email / password fields

```dart
SmartLocationField(
  controller: controller.emailController,
  title: "Email",
  hintText: "Enter your Email",
  keyboardType: TextInputType.emailAddress,
  isValidator: true,
  validator: controller.validateEmail,
  prefixIcon: Icons.email_outlined,
),

SmartLocationField(
  controller: controller.passwordController,
  title: "Password",
  hintText: "Enter your password",
  isValidator: true,
  validator: controller.validatePassword,
  obscureText: true,
  isObscureIcon: true,
  // uses the default visibility icons unless you set
  // obscureIcon/unObscureIcon or obscureImagePath/unObscureImagePath
),
```

### Country-only search

```dart
SmartLocationField(
  controller: controller.countryController,
  title: "Country",
  hintText: "Search a country",
  searchLevel: LocationSearchLevel.country,
  apiKey: "YOUR_GOOGLE_API_KEY",
  onLocationSelected: (name, placeId, lat, lng, details) {
    debugPrint('Country: $name (${details['countryCode']}) $lat,$lng');
  },
),
```

### Normal location search (addresses, areas, landmarks)

```dart
SmartLocationField(
  controller: controller.locationController,
  title: "Location",
  hintText: "Search a location",
  searchLevel: LocationSearchLevel.location,
  apiKey: "YOUR_GOOGLE_API_KEY",
  onLocationSelected: (name, placeId, lat, lng, details) {
    debugPrint('Location: $name  $lat,$lng');
  },
),
```

### State-only search, scoped to one country

```dart
SmartLocationField(
  controller: controller.stateController,
  title: "State",
  hintText: "Search a state",
  searchLevel: LocationSearchLevel.state,
  restrictToCountries: const ['in'],
  apiKey: "YOUR_GOOGLE_API_KEY",
  onLocationSelected: (name, placeId, lat, lng, details) {
    debugPrint('State: $name, country: ${details['countryName']}');
  },
),
```

### City-only search, biased to the user's current location

```dart
SmartLocationField(
  controller: controller.cityController,
  title: "City",
  hintText: "Search a city",
  searchLevel: LocationSearchLevel.city,
  apiKey: "YOUR_GOOGLE_API_KEY",
  lat: double.tryParse(controller.lat.value ?? "") ?? 0.0,
  lng: double.tryParse(controller.lng.value ?? "") ?? 0.0,
  onLocationSelected: (name, placeId, lat, lng, details) {
    debugPrint('City: $name  Lat/Lng: $lat,$lng');
  },
),
```

## `onLocationSelected` payload

```dart
void Function(
  String name,
  String? placeId,
  double? lat,
  double? lng,
  Map<String, dynamic> details,
)
```

`details` always carries `countryName`, `countryCode`, `stateName`,
`cityName`, and `formattedAddress` — regardless of `searchLevel` — so you can
read whichever level you need.

## Key parameters

| Param | Purpose |
|---|---|
| `searchLevel` | `none` / `country` / `state` / `city` / `location` |
| `apiKey` | Google Places API key |
| `apiCaller` | Override the `smart_api` call for this instance only |
| `restrictToCountries` | ISO-3166-1 alpha-2 codes, e.g. `['in']` |
| `lat` / `lng` | Bias point for search |
| `minSearchLength` | Characters before a search fires (default `2`) |
| `debounceDuration` | Debounce before hitting the API (default `350ms`) |
| `obscureText` / `isObscureIcon` | Password-field support |
| `prefixIcon`/`prefixImagePath`, `suffixIcon`/`suffixImagePath` | Icon-or-image affixes |
| `validator` / `validatorText` | Full custom logic, or just a message |

See `example/` for a full running demo.

## Publishing this package

Once you're happy with it:

```bash
flutter pub publish --dry-run
flutter pub publish
```

(Fill in `homepage`/`repository` in `pubspec.yaml` first — `pub.dev` requires
a valid homepage or repository URL to publish. Also confirm the `smart_api`
dependency resolves correctly for whoever installs this package — a public
pub.dev consumer won't have access to a private git/path source unless you
adjust it.)
