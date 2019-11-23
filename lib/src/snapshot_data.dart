import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hasura_connect/src/hasura_connect_base.dart';
import 'package:hasura_connect/src/snapshot_info.dart';

import 'hydrated.dart';
import 'local_storage.dart';
import 'snapshot.dart';

class SnapshotData<T> extends Snapshot<T> {
  final Function _close;
  final void Function(SnapshotData) _renew;

  HasuraConnect _conn;

  ///Info about Snapshot [query] [variables] and [key]
  final SnapshotInfo info;
  HydratedSubject<T> _controller;
  T Function(String) _hydrated;
  String Function(T) _persist;

  @override
  T get value => _controller.value;

  final Stream<T> _streamInit;
  StreamSubscription _streamSubscription;

  SnapshotData(this.info, this._streamInit, this._close, this._renew,
      {HasuraConnect conn,
      T Function(String) hydrated,
      String Function(T) persist}) {
    _conn = conn;
    _hydrated = hydrated ??
        (String i) {
          return i == null ? null : jsonDecode(i);
        };
    _persist = persist ??
        (obj) {
          return obj == null ? null : jsonEncode(obj);
        };

    _controller = HydratedSubject<T>(
      info.key,
      hydrate: _hydrated,
      persist: _persist,
    );

    _streamSubscription = _streamInit.listen((data) {
      if (!_controller.isClosed) {
        _controller.add(data);
      }
    }, onError: (e) {
      print("ERRO");
      //_controller.addError(e);
    });
  }

  @override
  Future mutation(String doc,
      {Map<String, dynamic> variables, T Function(T) onNotify}) {
    if (onNotify != null) {
      T data = onNotify(_controller.value);
      _controller.add(data);
    }
    return _conn.mutation(doc, variables: variables, cache: true);
  }

  SnapshotData<S> _copyWith<S>(
      {SnapshotInfo info,
      Stream streamInit,
      Function close,
      HasuraConnect conn,
      S Function(String) hydrated,
      String Function(S) persist,
      Function(Snapshot) renew}) {
    return SnapshotData<S>(
      info ?? this.info,
      streamInit ?? this._streamInit,
      close ?? this.close,
      renew ?? this._renew,
      conn: conn ?? this._conn,
      hydrated: hydrated ?? this._hydrated,
      persist: persist ?? this._persist,
    );
  }

  @override
  Snapshot<S> convert<S>(S Function(dynamic) convert,
      {@required String Function(S object) cachePersist}) {
    assert(cachePersist != null);

    var _h = (String s) {
      return s == null ? null : convert(jsonDecode(s));
    };

    var _p = (S obj) {
      return obj == null ? null : cachePersist(obj);
    };

    var v = _copyWith<S>(
        streamInit: _streamInit.map<S>(convert), hydrated: _h, persist: _p);
    return v;
  }

  @override
  void changeVariable(Map<String, dynamic> v) {
    info.variables = v;
    if (info.isQuery) {
      _sendNewQuery();
    } else {
      _renew(this);
    }
  }

  _sendNewQuery() async {
    final data = await _conn.query(info.query, variables: info.variables);
    _controller.add(data);
  }

  @override
  Future cleanCache() async {
    LocalStorage _localStorage = LocalStorage();
    await _localStorage.remove("${info.key}");
  }

  @override
  StreamSubscription<T> listen(void Function(T event) onData,
      {Function onError, void Function() onDone, bool cancelOnError}) {
    return _controller.listen(onData,
        cancelOnError: cancelOnError, onError: onError, onDone: onDone);
  }

  @override
  Future close() async {
    await _streamSubscription.cancel();
    await _controller.close();
    await _close();
  }
}
