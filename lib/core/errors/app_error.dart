/// Centralized error hierarchy for the Local-First architecture.
/// Modules raise these instead of leaking storage / network specifics.
sealed class AppError implements Exception {
  const AppError(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class ValidationError extends AppError {
  const ValidationError(super.message);
}

class NotFoundError extends AppError {
  const NotFoundError(super.message);
}

class DatabaseError extends AppError {
  const DatabaseError(super.message);
}

class CommunicationError extends AppError {
  const CommunicationError(super.message);
}

class PermissionError extends AppError {
  const PermissionError(super.message);
}

class OfflineError extends AppError {
  const OfflineError(super.message);
}

class BusinessRuleError extends AppError {
  const BusinessRuleError(super.message);
}
