import 'package:mocktail/mocktail.dart';
// BEGIN_ADS
import 'package:blueprint_app/features/ads/data/google_mobile_ads_gateway.dart';
import 'package:blueprint_app/features/ads/domain/ads_repository.dart';
// END_ADS
import 'package:blueprint_app/features/auth/data/firebase_auth_repository.dart';
import 'package:blueprint_app/features/user_profile/data/firebase_user_repository.dart';

class MockAuthRepository extends Mock implements FirebaseAuthRepository {}

class MockUserRepository extends Mock implements FirebaseUserRepository {}

// BEGIN_ADS
class MockGoogleMobileAdsGateway extends Mock
    implements GoogleMobileAdsGateway {}

class MockLoadedAd extends Mock implements LoadedAd {}

class MockAdsRepository extends Mock implements AdsRepository {}

// END_ADS
