import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:smart_api/smart_api.dart';


/// How narrow the Google search should be.
///
/// - [none]     → plain TextFormField, no Google call at all (normal email/
///                password style field).
/// - [country]  → only returns countries (e.g. "India").
/// - [state]    → only returns states / provinces (e.g. "Punjab").
/// - [city]     → only returns cities / localities (e.g. "Patiala").
/// - [location] → normal, unrestricted location search: addresses, areas,
///                landmarks, businesses — anything Google Places returns.
enum LocationSearchLevel { none, country, state, city, location }

/// Signature for the actual network call, kept as an escape hatch.
///
/// By default every Google Places hit goes through [_defaultSmartApiGet]
/// below (built on `smart_api` ^1.1.1). Pass [SmartLocationField.apiCaller]
/// only if you need to override that for one field.
typedef SmartApiCaller = Future<Map<String, dynamic>?> Function(String url);

/// ---------------------------------------------------------------------
/// smart_api wiring (^1.1.1)
/// ---------------------------------------------------------------------
/// Uses `SmartApiClient.instance.get(...)`. The client is called through
/// `dynamic` on purpose so a small signature difference between smart_api
/// versions can never turn into a compile error; anything that still goes
/// wrong is caught and logged, and the field simply shows no suggestions.
Future<Map<String, dynamic>?> _defaultSmartApiGet(String url) async {
  try {
    final dynamic client = SmartApiClient.instance;
    dynamic res;
    try {
      // Raw JSON straight through (Google's body has no success/data
      // envelope, so no typed model is needed).
      res = await client.get(url, fromJson: (dynamic json) => json);
    } on NoSuchMethodError {
      res = await client.get(url);
    }
    return _asJsonMap(res);
  } catch (e) {
    log('SmartLocationField (smart_api) error: $e');
    return null;
  }
}

/// Pulls the Google JSON map out of whatever smart_api handed back: the map
/// itself, a JSON string, or a response object carrying it in `.data`.
Map<String, dynamic>? _asJsonMap(dynamic res) {
  if (res == null) return null;

  Map<String, dynamic>? fromValue(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is String && v.trim().startsWith('{')) {
      final decoded = json.decode(v);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  final direct = fromValue(res);
  if (direct != null) return direct;

  // Response-object case.
  for (final read in <dynamic Function()>[
    () => res.data,
    () => res.raw,
    () => res.body,
  ]) {
    try {
      final m = fromValue(read());
      if (m != null) return m;
    } catch (_) {
      // property doesn't exist on this response type — try the next one
    }
  }
  return null;
}

class SmartLocationField extends StatefulWidget {
  // ---- core field ---------------------------------------------------
  final TextEditingController? controller;
  final String? title;
  final String? hintText;
  final Color? titleColor;
  final Color? hintTextColor;
  final Color? textColor;
  final Color? cursorColor;
  final Color? fillColor;
  final bool filled;
  final double titleSpacing;
  final double fontSize;
  final double hintSize;
  final FontWeight? titleFontWeight;

  // ---- borders --------------------------------------------------------
  final double fieldBorderRadius;
  final double enableBorderWidth;
  final double focusedBorderWidth;
  final Color enableBorderColor;
  final Color focusBorderColor;
  final Color errorBorderColor;

  // ---- behaviour --------------------------------------------------------
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int maxLines;

  /// Full control, user's choice: pass your own validator function and it
  /// is used as-is (whatever it returns wins).
  final String? Function(String?)? validator;
  final bool isValidator;

  /// Simpler option, user's choice: just a message. If [validator] isn't
  /// given, a built-in "required" check uses this as the error text
  /// (falls back to "This field is required" if neither is given).
  final String? validatorText;
  final void Function(String)? onChanged;
  final VoidCallback? onTap;

  // ---- password support (so this same widget covers the "normal" case) --
  final bool obscureText;

  /// Turns on the show/hide toggle button. The toggle itself can be an
  /// icon OR an image — whichever you pass wins for each state:
  /// [obscureImagePath]/[unObscureImagePath] take priority over
  /// [obscureIcon]/[unObscureIcon] when both are set. Image paths starting
  /// with `http://`/`https://` load as network images, anything else as
  /// an asset.
  final bool isObscureIcon;
  final IconData obscureIcon;
  final IconData unObscureIcon;
  final String? obscureImagePath;
  final String? unObscureImagePath;

  // ---- prefix / suffix, dynamic icon-or-image, per instance --------
  /// Same icon-or-image choice as the password toggle: set [prefixIcon]
  /// for an icon, or [prefixImagePath] for an image (asset or network) —
  /// image wins if both are set.
  final IconData? prefixIcon;
  final String? prefixImagePath;
  final Color? prefixIconColor;
  final double? prefixIconSize;
  final VoidCallback? onPrefixTap;

  /// Static suffix icon/image for non-password fields. Ignored while
  /// [isObscureIcon] is true (the password toggle takes that slot) and
  /// ignored while a search is loading (the spinner takes it instead).
  final IconData? suffixIcon;
  final String? suffixImagePath;
  final Color? suffixIconColor;
  final double? suffixIconSize;
  final VoidCallback? onSuffixTap;

  /// Default affix (prefix/suffix/toggle) icon/image size when a more
  /// specific size isn't given.
  final double affixIconSize;

  // ---- Google search ------------------------------------------------
  /// [LocationSearchLevel.none] → behaves like a normal TextFormField.
  /// [LocationSearchLevel.location] → normal, unrestricted location search.
  final LocationSearchLevel searchLevel;
  final String? apiKey;

  /// Override the network call used for Google Places (see
  /// [SmartApiCaller]). Leave null to use `smart_api` via
  /// [_defaultSmartApiGet].
  final SmartApiCaller? apiCaller;

  /// Optional ISO-3166-1 alpha-2 codes to restrict results to, e.g.
  /// `['in']`. Useful when searching states/cities inside one country.
  final List<String>? restrictToCountries;

  /// Optional bias point (e.g. user's current lat/lng) — nudges results
  /// toward that area without hard-restricting them.
  final double? lat;
  final double? lng;

  final int minSearchLength;
  final Duration debounceDuration;
  final double suggestionSheetHeight;
  final Color? sheetColor;
  final Color? sheetTextColor;

  /// Show a leading icon/image per suggestion row. Set [suggestionIcon]
  /// or [suggestionImagePath] to override the built-in per-level icon
  /// (globe for country, map for state, city outline for city); image
  /// wins if both are set. Set [showLevelIcon] to false to hide it.
  final bool showLevelIcon;
  final IconData? suggestionIcon;
  final String? suggestionImagePath;

  /// Fired once the user taps a suggestion. [details] additionally carries
  /// `countryName`, `countryCode`, `stateName`, `cityName`,
  /// `formattedAddress` (all `String?`) so you can use whichever level you
  /// need regardless of [searchLevel].
  final void Function(
      String name,
      String? placeId,
      double? lat,
      double? lng,
      Map<String, dynamic> details,
      )?
  onLocationSelected;

  const SmartLocationField({
    super.key,
    this.controller,
    this.title,
    this.hintText,
    this.titleColor,
    this.hintTextColor,
    this.textColor,
    this.cursorColor,
    this.fillColor,
    this.filled = true,
    this.titleSpacing = 8,
    this.fontSize = 14,
    this.hintSize = 12,
    this.titleFontWeight,
    this.fieldBorderRadius = 12,
    this.enableBorderWidth = 1,
    this.focusedBorderWidth = 2,
    this.enableBorderColor = Colors.grey,
    this.focusBorderColor = Colors.teal,
    this.errorBorderColor = Colors.red,
    this.keyboardType,
    this.textInputAction,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.validator,
    this.isValidator = false,
    this.validatorText,
    this.onChanged,
    this.onTap,
    this.obscureText = false,
    this.isObscureIcon = false,
    this.obscureIcon = Icons.visibility_off_outlined,
    this.unObscureIcon = Icons.visibility_outlined,
    this.obscureImagePath,
    this.unObscureImagePath,
    this.prefixIcon,
    this.prefixImagePath,
    this.prefixIconColor,
    this.prefixIconSize,
    this.onPrefixTap,
    this.suffixIcon,
    this.suffixImagePath,
    this.suffixIconColor,
    this.suffixIconSize,
    this.onSuffixTap,
    this.affixIconSize = 20,
    this.searchLevel = LocationSearchLevel.none,
    this.apiKey,
    this.apiCaller,
    this.restrictToCountries,
    this.lat,
    this.lng,
    this.minSearchLength = 2,
    this.debounceDuration = const Duration(milliseconds: 350),
    this.suggestionSheetHeight = 220,
    this.sheetColor,
    this.sheetTextColor,
    this.showLevelIcon = true,
    this.suggestionIcon,
    this.suggestionImagePath,
    this.onLocationSelected,
  });

  @override
  State<SmartLocationField> createState() => _SmartLocationFieldState();
}

class _SmartLocationFieldState extends State<SmartLocationField> {
  late final FocusNode _focusNode;
  late bool _isObscure;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<dynamic> _predictions = [];
  Timer? _debounceTimer;
  bool _loading = false;

  bool get _isSearchField => widget.searchLevel != LocationSearchLevel.none;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocusChange);
    _isObscure = widget.obscureText;
  }

  @override
  void didUpdateWidget(covariant SmartLocationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.obscureText != oldWidget.obscureText) {
      _isObscure = widget.obscureText;
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) _removeOverlay();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _removeOverlay();
    _focusNode.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // ------------------------------------------------------------------
  // Networking — every Google hit goes through this one place, so
  // swapping the smart_api call is a one-line change (pass `apiCaller`),
  // or a one-function edit in `_defaultSmartApiGet` above.
  // ------------------------------------------------------------------

  Future<Map<String, dynamic>?> _hit(String url) {
    if (widget.apiCaller != null) return widget.apiCaller!(url);
    return _defaultSmartApiGet(url);
  }

  String? _typesParam() {
    switch (widget.searchLevel) {
      case LocationSearchLevel.country:
      case LocationSearchLevel.state:
      // Google only exposes a handful of fixed "types" values; country
      // and state both live under the broader "(regions)" bucket, so we
      // narrow it further on the client once results come back.
        return '(regions)';
      case LocationSearchLevel.city:
        return '(cities)';
      case LocationSearchLevel.location:
      case LocationSearchLevel.none:
        // No "types" filter → Google returns every kind of place.
        return null;
    }
  }

  List<String> _typesOf(dynamic prediction) =>
      List<String>.from(prediction['types'] ?? const []);

  void _onChangedText(String value) {
    widget.onChanged?.call(value);
    if (!_isSearchField) return;

    _debounceTimer?.cancel();
    final query = value.trim();

    if (query.length < widget.minSearchLength) {
      setState(() => _predictions = []);
      _removeOverlay();
      return;
    }

    _debounceTimer = Timer(
      widget.debounceDuration,
          () => _fetchPredictions(query),
    );
  }

  Future<void> _fetchPredictions(String query) async {
    if (widget.apiKey == null || widget.apiKey!.trim().isEmpty) return;
    if (widget.controller != null && widget.controller!.text.trim() != query) {
      return;
    }

    setState(() => _loading = true);

    final types = _typesParam();
    final buffer = StringBuffer(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&key=${widget.apiKey}',
    );
    if (types != null) buffer.write('&types=${Uri.encodeComponent(types)}');

    if (widget.restrictToCountries != null &&
        widget.restrictToCountries!.isNotEmpty) {
      final components = widget.restrictToCountries!
          .map((c) => 'country:$c')
          .join('|');
      buffer.write('&components=${Uri.encodeComponent(components)}');
    }

    final hasBias =
        widget.lat != null &&
            widget.lng != null &&
            widget.lat != 0 &&
            widget.lng != 0;
    if (hasBias) {
      buffer.write('&location=${widget.lat},${widget.lng}&radius=50000');
    }

    final data = await _hit(buffer.toString());
    if (!mounted) return;
    setState(() => _loading = false);

    if (data == null) return;
    if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
      log('SmartLocationField autocomplete error: ${data['status']}');
      return;
    }

    var predictions = (data['predictions'] as List?) ?? const [];

    if (widget.searchLevel == LocationSearchLevel.country) {
      predictions = predictions
          .where((p) => _typesOf(p).contains('country'))
          .toList();
    } else if (widget.searchLevel == LocationSearchLevel.state) {
      predictions = predictions
          .where((p) => _typesOf(p).contains('administrative_area_level_1'))
          .toList();
    }

    if (!mounted) return;
    setState(() => _predictions = predictions);

    if (_predictions.isNotEmpty) {
      if (_overlayEntry == null) {
        _showOverlay();
      } else {
        _overlayEntry!.markNeedsBuild();
      }
    } else {
      _removeOverlay();
    }
  }

  Future<Map<String, dynamic>?> _placeDetails(String placeId) async {
    if (widget.apiKey == null || widget.apiKey!.trim().isEmpty) return null;

    final url =
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${Uri.encodeComponent(placeId)}'
        '&fields=geometry,address_component,formatted_address'
        '&key=${widget.apiKey}';

    final data = await _hit(url);
    if (data == null || data['status'] != 'OK') {
      if (data != null) log('SmartLocationField details error: ${data['status']}');
      return null;
    }

    final result = data['result'];
    if (result == null) return null;

    final location = result['geometry']?['location'];
    final lat = (location?['lat'] as num?)?.toDouble();
    final lng = (location?['lng'] as num?)?.toDouble();
    final components = (result['address_components'] as List?) ?? const [];

    String? component(List<String> types, {bool shortName = false}) {
      for (final c in components) {
        final cTypes = List<String>.from(c['types'] ?? const []);
        if (types.any(cTypes.contains)) {
          final value = shortName
              ? c['short_name']?.toString()
              : c['long_name']?.toString();
          if (value != null && value.trim().isNotEmpty) return value.trim();
        }
      }
      return null;
    }

    final countryName = component(['country']);
    final countryCode = component(['country'], shortName: true);
    final stateName = component(['administrative_area_level_1']);
    final cityName = component([
      'locality',
      'postal_town',
      'administrative_area_level_2',
    ]);
    final formattedAddress = result['formatted_address']?.toString();

    String resolvedName;
    switch (widget.searchLevel) {
      case LocationSearchLevel.country:
        resolvedName = countryName ?? formattedAddress ?? '';
        break;
      case LocationSearchLevel.state:
        resolvedName = stateName ?? formattedAddress ?? '';
        break;
      case LocationSearchLevel.city:
        resolvedName = cityName ?? formattedAddress ?? '';
        break;
      case LocationSearchLevel.location:
      case LocationSearchLevel.none:
        resolvedName = formattedAddress ?? '';
        break;
    }

    return {
      'name': resolvedName,
      'lat': lat,
      'lng': lng,
      'placeId': placeId,
      'countryName': countryName,
      'countryCode': countryCode,
      'stateName': stateName,
      'cityName': cityName,
      'formattedAddress': formattedAddress,
    };
  }

  Future<void> _selectPrediction(dynamic prediction) async {
    final placeId = prediction['place_id']?.toString();
    final description = prediction['description']?.toString() ?? '';
    if (placeId == null || placeId.isEmpty) return;

    final details = await _placeDetails(placeId);
    if (!mounted) return;

    // Normal location search: keep the suggestion text the user tapped
    // ("Taj Mahal, Agra, Uttar Pradesh, India") rather than a trimmed name.
    final preferDescription = widget.searchLevel == LocationSearchLevel.location &&
        description.isNotEmpty;
    final resolvedName = preferDescription
        ? description
        : (details?['name'] as String?)?.isNotEmpty == true
            ? details!['name'] as String
            : description;

    widget.controller?.text = resolvedName;
    widget.onChanged?.call(resolvedName);

    setState(() => _predictions = []);
    _removeOverlay();

    widget.onLocationSelected?.call(
      resolvedName,
      placeId,
      details?['lat'] as double?,
      details?['lng'] as double?,
      details ?? const {},
    );
  }

  // ------------------------------------------------------------------
  // Icon-or-image: every affix (prefix, suffix, password toggle,
  // suggestion leading icon) goes through this so each field instance
  // can independently decide "icon" or "image" for each slot.
  // ------------------------------------------------------------------

  bool _isNetworkPath(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  Widget? _iconOrImage({
    IconData? icon,
    String? imagePath,
    double? size,
    Color? color,
  }) {
    final resolvedSize = size ?? widget.affixIconSize;
    if (imagePath != null && imagePath.trim().isNotEmpty) {
      return _isNetworkPath(imagePath)
          ? Image.network(
        imagePath,
        height: resolvedSize,
        width: resolvedSize,
        color: color,
        fit: BoxFit.contain,
      )
          : Image.asset(
        imagePath,
        height: resolvedSize,
        width: resolvedSize,
        color: color,
        fit: BoxFit.contain,
      );
    }
    if (icon != null) {
      return Icon(icon, size: resolvedSize, color: color);
    }
    return null;
  }

  Widget? _affix({
    IconData? icon,
    String? imagePath,
    double? size,
    Color? color,
    VoidCallback? onTap,
  }) {
    final child = _iconOrImage(
      icon: icon,
      imagePath: imagePath,
      size: size,
      color: color,
    );
    if (child == null) return null;
    if (onTap == null) {
      return Padding(padding: const EdgeInsets.all(12), child: child);
    }
    return IconButton(icon: child, onPressed: onTap);
  }

  Widget? _buildPrefix() {
    if (widget.prefixIcon == null &&
        (widget.prefixImagePath ?? '').isEmpty) {
      return null;
    }
    return _affix(
      icon: widget.prefixIcon,
      imagePath: widget.prefixImagePath,
      size: widget.prefixIconSize,
      color: widget.prefixIconColor ?? widget.hintTextColor ?? Colors.white70,
      onTap: widget.onPrefixTap,
    );
  }

  Widget? _buildSuffix() {
    if (widget.isObscureIcon) {
      return _affix(
        icon: _isObscure ? widget.obscureIcon : widget.unObscureIcon,
        imagePath: _isObscure
            ? widget.obscureImagePath
            : widget.unObscureImagePath,
        size: widget.affixIconSize,
        color: widget.hintTextColor ?? Colors.white70,
        onTap: () => setState(() => _isObscure = !_isObscure),
      );
    }

    if (widget.suffixIcon != null || (widget.suffixImagePath ?? '').isNotEmpty) {
      return _affix(
        icon: widget.suffixIcon,
        imagePath: widget.suffixImagePath,
        size: widget.suffixIconSize,
        color: widget.suffixIconColor ?? widget.hintTextColor ?? Colors.white70,
        onTap: widget.onSuffixTap,
      );
    }

    if (_loading && _isSearchField) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return null;
  }

  IconData _defaultLevelIcon() {
    switch (widget.searchLevel) {
      case LocationSearchLevel.country:
        return Icons.public;
      case LocationSearchLevel.state:
        return Icons.map_outlined;
      case LocationSearchLevel.city:
        return Icons.location_city;
      case LocationSearchLevel.location:
        return Icons.place_outlined;
      case LocationSearchLevel.none:
        return Icons.location_on_outlined;
    }
  }

  Widget? _suggestionLeading() {
    if (!widget.showLevelIcon) return null;
    return _iconOrImage(
      icon: widget.suggestionIcon ?? _defaultLevelIcon(),
      imagePath: widget.suggestionImagePath,
      size: 18,
      color: widget.sheetTextColor ?? Colors.white70,
    );
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 4),
            child: Material(
              color: widget.sheetColor ?? const Color(0xFF1E2530),
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: widget.suggestionSheetHeight,
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _predictions.length,
                  itemBuilder: (context, index) {
                    final item = _predictions[index];
                    final description =
                        item['description']?.toString() ?? '';
                    return ListTile(
                      dense: true,
                      minVerticalPadding: 0,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      leading: _suggestionLeading(),
                      title: Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.sheetTextColor ?? Colors.white,
                        ),
                      ),
                      onTap: () => _selectPrediction(item),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  InputBorder _border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(widget.fieldBorderRadius),
    borderSide: BorderSide(color: color, width: width),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if ((widget.title ?? '').isNotEmpty) ...[
          Text(
            widget.title!,
            style: TextStyle(
              color: widget.titleColor ?? Colors.white,
              fontWeight: widget.titleFontWeight ?? FontWeight.w600,
              fontSize: 13,
            ),
          ),
          SizedBox(height: widget.titleSpacing),
        ],
        CompositedTransformTarget(
          link: _layerLink,
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            autofocus: widget.autofocus,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            obscureText: _isObscure,
            obscuringCharacter: '*',
            onTap: widget.onTap,
            onChanged: _onChangedText,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: widget.isValidator
                ? (widget.validator ??
                    (value) => (value == null || value.trim().isEmpty)
                    ? (widget.validatorText ?? 'This field is required')
                    : null)
                : null,
            style: TextStyle(
              color: widget.textColor ?? Colors.white,
              fontSize: widget.fontSize,
            ),
            cursorColor: widget.cursorColor ?? widget.focusBorderColor,
            decoration: InputDecoration(
              isDense: true,
              filled: widget.filled,
              fillColor: widget.fillColor ?? const Color(0xFF1E2530),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: widget.hintTextColor ?? Colors.white38,
                fontSize: widget.hintSize,
              ),
              prefixIcon: _buildPrefix(),
              enabledBorder: _border(
                widget.enableBorderColor,
                widget.enableBorderWidth,
              ),
              disabledBorder: _border(
                widget.enableBorderColor,
                widget.enableBorderWidth,
              ),
              focusedBorder: _border(
                widget.focusBorderColor,
                widget.focusedBorderWidth,
              ),
              errorBorder: _border(widget.errorBorderColor, 1),
              focusedErrorBorder: _border(widget.errorBorderColor, 2),
              suffixIcon: _buildSuffix(),
            ),
          ),
        ),
      ],
    );
  }
}