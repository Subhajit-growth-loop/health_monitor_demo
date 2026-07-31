// Central provider registry — import this file to access any app-level provider.
export '../core/network/network_api_services.dart' show dioProvider;
export '../core/settings/app_settings.dart' show sharedPreferencesProvider;
export '../features/dashboard/presentation/view_model/health_view_model.dart'
    show
        databaseProvider,
        connectivityServiceProvider,
        localDataSourceProvider,
        platformDataSourceProvider,
        remoteDataSourceProvider,
        healthRepositoryProvider,
        healthExportServiceProvider,
        healthChangesProvider;
export '../features/onboarding/presentation/view_model/onboarding_view_model.dart'
    show
        onboardingApiProvider,
        onboardingRepositoryProvider,
        onboardingControllerProvider,
        connectedSourcesProvider;
export '../features/auth/presentation/view_model/auth_view_model.dart'
    show authViewModelProvider;
