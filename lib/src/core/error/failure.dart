sealed class Failure {
  const Failure(this.message, {this.cause});

  final String message;
  final Object? cause;
}

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.cause});
}

final class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.cause});
}

final class PlatformFailure extends Failure {
  const PlatformFailure(super.message, {super.cause});
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, {super.cause});
}
