import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/drawing_models.dart';
import '../utils/drawing_exchange.dart';

class CloudDrawingSummary {
  final String drawingId;
  final String name;
  final DateTime updatedAt;
  final bool hasThumbnail;

  const CloudDrawingSummary({
    required this.drawingId,
    required this.name,
    required this.updatedAt,
    required this.hasThumbnail,
  });

  factory CloudDrawingSummary.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final ts = data['updatedAt'];
    final updated = ts is Timestamp
        ? ts.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
    return CloudDrawingSummary(
      drawingId: id,
      name: (data['name'] as String?) ?? 'Untitled Drawing',
      updatedAt: updated,
      hasThumbnail: (data['hasThumbnail'] as bool?) ?? false,
    );
  }
}

class CloudSyncService {
  static String _requireUid() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Bạn chưa đăng nhập.');
    }
    return user.uid;
  }

  static DocumentReference<Map<String, dynamic>> _drawingDocRef({
    required String uid,
    required String drawingId,
  }) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('drawings')
        .doc(drawingId);
  }

  static String _jsonPath({required String uid, required String drawingId}) {
    return 'users/$uid/drawings/$drawingId.json';
  }

  static String _thumbPath({required String uid, required String drawingId}) {
    return 'users/$uid/drawings/$drawingId.thumb.png';
  }

  static Future<void> uploadDrawing({
    required String drawingId,
    required String name,
    required DrawingDocument doc,
    Uint8List? thumbnailPngBytes,
  }) async {
    final uid = _requireUid();

    DrawingExchangeFile.validateDocSize(doc);

    final jsonText = DrawingExchangeFile.exportToPrettyJson(
      drawingId: drawingId,
      name: name,
      doc: doc,
    );

    final jsonBytes = Uint8List.fromList(utf8.encode(jsonText));

    final jsonRef = FirebaseStorage.instance.ref(
      _jsonPath(uid: uid, drawingId: drawingId),
    );

    await jsonRef.putData(
      jsonBytes,
      SettableMetadata(
        contentType: 'application/json; charset=utf-8',
        cacheControl: 'no-cache',
      ),
    );

    final hasThumb = thumbnailPngBytes != null && thumbnailPngBytes.isNotEmpty;
    if (hasThumb) {
      final thumbRef = FirebaseStorage.instance.ref(
        _thumbPath(uid: uid, drawingId: drawingId),
      );
      await thumbRef.putData(
        thumbnailPngBytes,
        SettableMetadata(contentType: 'image/png', cacheControl: 'no-cache'),
      );
    }

    await _drawingDocRef(uid: uid, drawingId: drawingId).set({
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
      'hasThumbnail': hasThumb,
      'storageJsonPath': _jsonPath(uid: uid, drawingId: drawingId),
      if (hasThumb)
        'storageThumbPath': _thumbPath(uid: uid, drawingId: drawingId),
    }, SetOptions(merge: true));
  }

  static Future<List<CloudDrawingSummary>> listDrawings() async {
    final uid = _requireUid();
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('drawings')
        .orderBy('updatedAt', descending: true)
        .get();

    return snap.docs
        .map((d) => CloudDrawingSummary.fromFirestore(d.id, d.data()))
        .toList(growable: false);
  }

  static Future<(String jsonText, Uint8List? thumbnailPngBytes)>
  downloadDrawing({required String drawingId}) async {
    final uid = _requireUid();

    final meta = await _drawingDocRef(uid: uid, drawingId: drawingId).get();
    if (!meta.exists) {
      throw StateError('Không tìm thấy bản vẽ trên cloud.');
    }

    final data = meta.data() ?? <String, dynamic>{};
    final jsonPath =
        (data['storageJsonPath'] as String?) ??
        _jsonPath(uid: uid, drawingId: drawingId);
    final jsonRef = FirebaseStorage.instance.ref(jsonPath);

    final jsonBytes = await jsonRef.getData(50 * 1024 * 1024);
    if (jsonBytes == null) {
      throw StateError('Không tải được JSON từ cloud.');
    }
    final jsonText = utf8.decode(jsonBytes, allowMalformed: true);

    Uint8List? thumb;
    final thumbPath = data['storageThumbPath'] as String?;
    if (thumbPath != null) {
      try {
        thumb = await FirebaseStorage.instance
            .ref(thumbPath)
            .getData(10 * 1024 * 1024);
      } catch (_) {
        thumb = null;
      }
    }

    return (jsonText, thumb);
  }
}
