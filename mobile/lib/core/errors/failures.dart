abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No active internet connection. Please check your network.']);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'An error occurred while connecting to the server.']);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
