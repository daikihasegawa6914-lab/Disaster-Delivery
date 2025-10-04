# Copilot Instructions for Disaster Delivery App

## 🏗️ Project Overview

This is a **Flutter disaster delivery app** for delivery drivers during emergency situations. The app connects delivery personnel with evacuation shelters and disaster victims through Firebase integration.

**Key Characteristics:**
- 8-day hackathon project with 3-minute presentation format
- Single developer learning project with Firebase basics
- Japanese comments throughout codebase (👶 emoji marks beginner-friendly explanations)
- Security-first approach with comprehensive error handling

## 📁 Architecture Pattern

### Core Structure
```
lib/
├── main.dart                    # App entry point with Firebase & security setup
├── main_screen.dart            # Tab navigation (DeliveryMapScreen, ShelterScreen)
├── models.dart                 # Data models (DeliveryRequest, DeliveryPerson, Shelter)
├── services.dart               # Firebase & location services
├── security/                   # Security layer (mandatory for all operations)
│   ├── secure_error_handler.dart
│   ├── input_validator.dart
│   └── optimized_firestore.dart
├── delivery_map_screen.dart    # Google Maps with delivery requests
└── shelter_screen.dart         # Evacuation shelter information
```

### Data Flow Pattern
1. **Firebase Streams** → Real-time data binding
2. **Security Layer** → Input validation & error sanitization
3. **Location Services** → GPS integration for delivery routing
4. **State Management** → Simple setState (no complex state management)

## 🔥 Firebase Integration Patterns

### Firestore Collections
- `requests` - Delivery requests with status tracking
- `deliveries` - Completed delivery records
- `shelters` - Evacuation shelter information

### Security Rules Philosophy
Located in `firestore.rules` - implements comprehensive input validation:
- Coordinate bounds validation (Tokyo area: 35-36°N, 139-140.5°E)
- String sanitization against injection attacks
- Rate limiting (5 requests per minute)
- Read-only for critical disaster data

### Service Layer Pattern
In `services.dart`:
```dart
// Stream-based real-time updates
FirebaseService.getWaitingRequests()
FirebaseService.getMyDeliveries(deliveryPersonId)

// Status management
FirebaseService.startDelivery(requestId, deliveryPersonId)
FirebaseService.completeDelivery(requestId)
```

## 🛡️ Security-First Development

### Mandatory Security Layer
Every operation must go through `security/` modules:
- **SecureErrorHandler**: Sanitizes sensitive data in error messages (API keys, emails, phone numbers)
- **InputValidator**: Validates all user inputs before Firebase operations
- **OptimizedFirestore**: Manages offline support and connection optimization

### Error Handling Pattern
```dart
// In main.dart - Global error handling setup
SecureErrorHandler.setupGlobalErrorHandling();
SecureErrorHandler.logSecureError(
  operation: 'Operation Name',
  error: errorObject,
  level: SecurityLevel.error,
);
```

## 🗺️ Google Maps Integration

### Location Service Pattern
```dart
// Current location with permission handling
LocationService.getCurrentLocation()
LocationService.calculateDistance(from, to)

// Coordinate validation for Tokyo disaster area
isValidCoordinates(lat, lng) // 35-36°N, 139-140.5°E
```

## 🎯 Development Workflow

### Setup Commands
```bash
# Firebase configuration (required first)
cp lib/firebase_options.dart.example lib/firebase_options.dart
# Edit with actual Firebase config values

# Dependencies
flutter pub get

# Run with Firebase connection
flutter run
```

### Testing Firebase Rules
```bash
# Deploy security rules
firebase deploy --only firestore:rules

# Test rules locally
firebase emulators:start --only firestore
```

## 🌟 Code Conventions

### Comment Style
- **👶** marks beginner-friendly explanations in Japanese
- **🛡️** indicates security-related code
- **🔥** marks Firebase operations
- **📍** for location/mapping features

### Model Pattern
Models in `models.dart` follow this structure:
```dart
class DeliveryRequest {
  // Factory constructor from Firestore
  factory DeliveryRequest.fromFirestore(DocumentSnapshot doc)
  
  // Method to convert to Firestore format
  Map<String, dynamic> toFirestore()
  
  // Immutable updates
  DeliveryRequest copyWith({...})
  
  // UI helper methods
  String get priorityColor  // 🔴🟡🟢
  String get statusIcon     // ⏳🚚✅
}
```

### Stream-Based UI Updates
```dart
// Real-time data binding pattern
StreamBuilder<List<DeliveryRequest>>(
  stream: FirebaseService.getWaitingRequests(),
  builder: (context, snapshot) {
    // Handle loading, error, data states
  },
)
```

## 🚨 Critical Integration Points

### Firebase Configuration
- Project ID: `disaster-delivery-app`
- Configuration files: `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`
- Dart options: `lib/firebase_options.dart` (template in `.example`)

### Google Maps API
- Requires API key in platform-specific configuration
- Map markers show delivery request status with emoji indicators
- Distance calculation for delivery optimization

### Environment-Specific Patterns
- Development: Uses Firebase emulators when available
- Production: `production_config.dart` for production settings
- Error logging: Memory-limited (50 entries max) for mobile performance

## 🔄 State Management Approach

**Deliberately Simple**: Uses `setState` and `StreamBuilder` instead of complex state management
- Suitable for 8-day development timeline
- Easier debugging for single developer
- Real-time updates handled by Firebase streams

## 🎨 UI Patterns

### Bottom Tab Navigation
`MainScreen` with `IndexedStack` for tab persistence:
- 🚚 Delivery Map (primary screen)
- 🏠 Shelter Information
- Future: Statistics/Settings tabs

### Material Design 3
- `ColorScheme.fromSeed(seedColor: Colors.blue)`
- Consistent blue theme for emergency service appearance
- Japanese text throughout interface

When working on this codebase, prioritize security validation, maintain the simple architecture pattern, and ensure all Firebase operations go through the established service layer.