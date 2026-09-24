import 'package:flutter/material.dart';
import 'package:smart_location_field/smart_location_field.dart';

// TODO: put a real Google Places API key here to try the search fields.
const String kGoogleApiKey = "YOUR_GOOGLE_API_KEY";

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'smart_location_field demo',
      theme: ThemeData.dark(useMaterial3: true),
      home: const DemoScreen(),
    );
  }
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final countryController = TextEditingController();
  final stateController = TextEditingController();
  final cityController = TextEditingController();
  final locationController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('smart_location_field demo')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Email — icon prefix, and "just a message" validator style.
              SmartLocationField(
                controller: emailController,
                title: "Email",
                hintText: "Enter your Email",
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
                isValidator: true,
                validatorText: "Email is required",
              ),
              const SizedBox(height: 16),

              // Password — obscure/unobscure icons; swap for
              // obscureImagePath/unObscureImagePath if you'd rather use
              // your own eye-icon artwork. "Full custom function" style
              // validator here.
              SmartLocationField(
                controller: passwordController,
                title: "Password",
                hintText: "Enter your password",
                obscureText: true,
                isObscureIcon: true,
                isValidator: true,
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Min 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Google search fields (need a real API key in kGoogleApiKey)',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),
              SmartLocationField(
                controller: countryController,
                title: "Country",
                hintText: "Search a country",
                prefixIcon: Icons.public,
                searchLevel: LocationSearchLevel.country,
                apiKey: kGoogleApiKey,
                onLocationSelected: (name, placeId, lat, lng, details) {
                  debugPrint('Country: $name  ${details['countryCode']}');
                },
              ),
              const SizedBox(height: 16),
              SmartLocationField(
                controller: stateController,
                title: "State",
                hintText: "Search a state",
                prefixIcon: Icons.map_outlined,
                searchLevel: LocationSearchLevel.state,
                restrictToCountries: const ['in'],
                apiKey: kGoogleApiKey,
                onLocationSelected: (name, placeId, lat, lng, details) {
                  debugPrint('State: $name  ${details['countryName']}');
                },
              ),
              const SizedBox(height: 16),
              SmartLocationField(
                controller: cityController,
                title: "City",
                hintText: "Search a city",
                // Example of using an image instead of an icon for the
                // prefix — point this at a real asset in your app:
                // prefixImagePath: 'assets/icons/city.png',
                prefixIcon: Icons.location_city,
                searchLevel: LocationSearchLevel.city,
                apiKey: kGoogleApiKey,
                onLocationSelected: (name, placeId, lat, lng, details) {
                  debugPrint('City: $name  Lat/Lng: $lat,$lng');
                },
              ),
              const SizedBox(height: 16),
              SmartLocationField(
                controller: locationController,
                title: "Location",
                hintText: "Search any location",
                prefixIcon: Icons.place_outlined,
                searchLevel: LocationSearchLevel.location,
                apiKey: kGoogleApiKey,
                onLocationSelected: (name, placeId, lat, lng, details) {
                  debugPrint('Location: $name  Lat/Lng: $lat,$lng');
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Form valid!')),
                    );
                  }
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
