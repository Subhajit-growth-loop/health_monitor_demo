import 'status.dart';

class ApiResponse<T> {
  final Status status;
  final T? data;
  final String? message;

  const ApiResponse._({required this.status, this.data, this.message});

  const ApiResponse.loading() : this._(status: Status.loading);
  const ApiResponse.completed(T data) : this._(status: Status.completed, data: data);
  const ApiResponse.error(String message) : this._(status: Status.error, message: message);

  bool get isLoading => status == Status.loading;
  bool get isCompleted => status == Status.completed;
  bool get isError => status == Status.error;
}
