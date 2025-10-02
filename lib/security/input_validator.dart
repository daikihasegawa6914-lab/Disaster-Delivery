// 🛡️ 入力値検証システム - XSS、SQLインジェクション、不正データ防止
// 無料で実装できる最強のセキュリティ対策

class InputValidator {
  // 📧 メールアドレス検証
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // 📱 電話番号検証（日本の形式 - 実際のパターン対応）
  static bool isValidPhoneNumber(String phone) {
    if (phone.isEmpty) return false;
    
    // 数字以外を除去
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // 携帯電話番号パターン (090, 080, 070, 050)
    if (RegExp(r'^(090|080|070|050)[0-9]{8}$').hasMatch(cleanPhone)) {
      return true;
    }
    
    // 固定電話番号パターン
    // 03-XXXX-XXXX (東京), 06-XXXX-XXXX (大阪), 052-XXX-XXXX (名古屋) など
    if (RegExp(r'^(0[1-9][0-9]{1,3})[0-9]{4,7}$').hasMatch(cleanPhone)) {
      return true;
    }
    
    // IP電話などその他のパターン
    if (RegExp(r'^(050)[0-9]{8}$').hasMatch(cleanPhone)) {
      return true;
    }
    
    return false;
  }

  // 🌐 国際電話番号検証（+81 形式）
  static bool isValidInternationalPhoneNumber(String phone) {
    if (phone.isEmpty) return false;
    
    // +81 で始まる日本の国際形式
    if (phone.startsWith('+81')) {
      final withoutCountryCode = phone.substring(3);
      // 先頭0を除いた日本の番号パターンチェック
      return RegExp(r'^(90|80|70|50)[0-9]{8}$').hasMatch(withoutCountryCode) ||
             RegExp(r'^([1-9][0-9]{1,3})[0-9]{4,7}$').hasMatch(withoutCountryCode);
    }
    
    return false;
  }

  // 🏠 住所検証
  static bool isValidAddress(String address) {
    if (address.isEmpty || address.length < 5 || address.length > 200) {
      return false;
    }
    // 危険な文字（XSS対策）をチェック
    return !RegExp(r'[<>"%;()&+]').hasMatch(address);
  }

  // 📦 アイテム名検証
  static bool isValidItemName(String itemName) {
    if (itemName.isEmpty || itemName.length > 100) return false;
    return !RegExp(r'[<>"%;()&+]').hasMatch(itemName);
  }

  // 👤 名前検証
  static bool isValidName(String name) {
    if (name.isEmpty || name.length > 50) return false;
    return !RegExp(r'[<>"%;()&+]').hasMatch(name);
  }

  // 🧹 文字列サニタイズ（危険な文字を除去）
  static String sanitizeString(String input) {
    return input
        .replaceAll(RegExp(r'[<>"%;()&+]'), '') // 危険な文字除去
        .replaceAll(RegExp(r'[\x00-\x1f]'), '') // 制御文字除去
        .trim();
  }

  // 📏 長さ制限チェック
  static bool isValidLength(String input, int maxLength) {
    return input.length <= maxLength && input.isNotEmpty;
  }

  // 🔢 優先度検証（1-4）
  static bool isValidPriority(int priority) {
    return priority >= 1 && priority <= 4;
  }

  // 📍 座標検証（東京近郊）
  static bool isValidCoordinates(double latitude, double longitude) {
    // 東京近郊の座標範囲をチェック（災害配達の範囲制限）
    return latitude >= 35.0 && latitude <= 36.0 &&
           longitude >= 139.0 && longitude <= 140.5;
  }

  // 🚨 配達依頼の包括的検証
  static ValidationResult validateDeliveryRequest({
    required String requesterName,
    required String requesterPhone,
    required String requesterEmail,
    required String address,
    required String itemName,
    required double latitude,
    required double longitude,
    required int priority,
  }) {
    final errors = <String>[];
    final sanitizedData = <String, dynamic>{};

    // 依頼者名検証
    if (!isValidName(requesterName)) {
      errors.add('依頼者名は1-50文字で、安全な文字のみ使用してください');
    } else {
      sanitizedData['requesterName'] = sanitizeString(requesterName);
    }

    // 電話番号検証
    if (!isValidPhoneNumber(requesterPhone)) {
      errors.add('有効な日本の電話番号を入力してください');
    } else {
      sanitizedData['requesterPhone'] = requesterPhone;
    }

    // メールアドレス検証
    if (!isValidEmail(requesterEmail)) {
      errors.add('有効なメールアドレスを入力してください');
    } else {
      sanitizedData['requesterEmail'] = requesterEmail;
    }

    // 住所検証
    if (!isValidAddress(address)) {
      errors.add('住所は5-200文字で、安全な文字のみ使用してください');
    } else {
      sanitizedData['address'] = sanitizeString(address);
    }

    // アイテム名検証
    if (!isValidItemName(itemName)) {
      errors.add('アイテム名は1-100文字で、安全な文字のみ使用してください');
    } else {
      sanitizedData['itemName'] = sanitizeString(itemName);
    }

    // 座標検証
    if (!isValidCoordinates(latitude, longitude)) {
      errors.add('位置情報が東京近郊の範囲外です');
    } else {
      sanitizedData['latitude'] = latitude;
      sanitizedData['longitude'] = longitude;
    }

    // 優先度検証
    if (!isValidPriority(priority)) {
      errors.add('優先度は1-4の範囲で指定してください');
    } else {
      sanitizedData['priority'] = priority;
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      sanitizedData: sanitizedData,
    );
  }

  // 🔍 配達者情報の検証
  static ValidationResult validateDelivererInfo({
    required String name,
    required double currentLatitude,
    required double currentLongitude,
  }) {
    final errors = <String>[];
    final sanitizedData = <String, dynamic>{};

    if (!isValidName(name)) {
      errors.add('配達者名は1-50文字で、安全な文字のみ使用してください');
    } else {
      sanitizedData['name'] = sanitizeString(name);
    }

    if (!isValidCoordinates(currentLatitude, currentLongitude)) {
      errors.add('現在位置が東京近郊の範囲外です');
    } else {
      sanitizedData['currentLatitude'] = currentLatitude;
      sanitizedData['currentLongitude'] = currentLongitude;
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      sanitizedData: sanitizedData,
    );
  }

  // 📊 統計データの検証（無料範囲内）
  static bool isValidStatisticsData(Map<String, dynamic> data) {
    // 基本的な統計データのみ許可
    final allowedKeys = ['date', 'requestCount', 'deliveryCount'];
    
    // 不正なキーをチェック
    for (final key in data.keys) {
      if (!allowedKeys.contains(key)) {
        return false;
      }
    }
    
    // 数値範囲チェック（無料枠保護）
    final requestCount = data['requestCount'] as int?;
    final deliveryCount = data['deliveryCount'] as int?;
    
    if (requestCount != null && (requestCount < 0 || requestCount > 1000)) {
      return false;
    }
    
    if (deliveryCount != null && (deliveryCount < 0 || deliveryCount > 1000)) {
      return false;
    }
    
    return true;
  }
}

// 🛡️ 検証結果クラス
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final Map<String, dynamic> sanitizedData;

  ValidationResult({
    required this.isValid,
    required this.errors,
    required this.sanitizedData,
  });

  // エラーメッセージを取得
  String getErrorMessage() {
    return errors.join('\n');
  }

  // 成功時のサニタイズされたデータを取得
  Map<String, dynamic>? getSafeData() {
    return isValid ? sanitizedData : null;
  }
}

// 🔒 セキュリティ例外クラス
class SecurityValidationException implements Exception {
  final String message;
  final List<String> errors;
  
  SecurityValidationException(this.message, this.errors);
  
  @override
  String toString() => 'SecurityValidationException: $message';
}

/// 💡 使用例：
/// 
/// ```dart
/// final validation = InputValidator.validateDeliveryRequest(
///   requesterName: userInput.name,
///   requesterPhone: userInput.phone,
///   requesterEmail: userInput.email,
///   address: userInput.address,
///   itemName: userInput.item,
///   latitude: location.latitude,
///   longitude: location.longitude,
///   priority: userInput.priority,
/// );
/// 
/// if (!validation.isValid) {
///   showErrorDialog(validation.getErrorMessage());
///   return;
/// }
/// 
/// // 安全なデータを使用
/// final safeData = validation.getSafeData()!;
/// await saveToFirestore(safeData);
/// ```