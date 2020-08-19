class Extensions {
  final dynamic path;
  final dynamic code;
  final dynamic validation;

  Extensions(this.path, this.code, this.validation);

  factory Extensions.fromJson(Map json) {
    return Extensions(json['path'], json['code'], json['validation']);
  }
}
