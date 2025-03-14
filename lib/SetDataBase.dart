// lib/SetDataBase.dart
import 'package:appwrite/appwrite.dart';

// Appwrite 設定
const String projectId = "67c37669001b422e83e6";
const String apiEndpoint = "https://cloud.appwrite.io/v1";
const String apiKey = "standard_0a0dcb13fd66a35f6a8b5d718c3125e051cf6cc090ec96c1913eee127c4406b741ec626834c97a57f9ea4c6ca5240437dd03ad425e0379d463feb8759abab4ecde4775a020c9e693a0e2fd30f6c7b6c93269d1fa109300471d7d134683d2b0bffd07beeb953cd598228c81cdfcb2d3e64e44ea41ec457654f75fc3b4a703f82d";
const String bucketId = "67c4efcb0000f7348f23";
const String databaseId = "67c37890000902e1e89b";
const String collectionId = "67c378f40032f3b1b9df";

Client client = Client()
  ..setEndpoint(apiEndpoint)
  ..setProject(projectId)
  ..setSelfSigned(status: true);

Databases database = Databases(client);
Storage storage = Storage(client);