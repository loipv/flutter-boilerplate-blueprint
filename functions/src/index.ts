/**
 * Firebase Cloud Functions entry point.
 *
 * This file ships with two starter functions to validate your setup:
 *   - helloWorld   — callable function, returns a greeting
 *   - onUserCreate — Firestore trigger, creates a user profile on first sign-in
 *
 * Delete or replace these once you have real functions.
 *
 * Deploy:
 *   make deploy-functions-staging
 *   make deploy-functions-prod
 *
 * Emulate locally:
 *   npm run serve
 */

import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions';

// Initialize the default Firebase Admin app.
// In Cloud Functions the runtime provides Application Default Credentials —
// no service account JSON needed here.
admin.initializeApp();

const db = admin.firestore();

// ─── Region ───────────────────────────────────────────────────────────────────
// Set to the region closest to your users.
// Must match the region configured in your Flutter FirebaseFunctions client:
//   FirebaseFunctions.instanceFor(region: 'us-central1')
const REGION = 'us-central1';

// ─── helloWorld (Callable) ────────────────────────────────────────────────────
//
// Callable functions are invoked from Flutter via:
//   final result = await FirebaseFunctions.instance
//     .httpsCallable('helloWorld')
//     .call({'name': 'World'});
//
// Authentication is enforced automatically — unauthenticated calls are rejected.

export const helloWorld = onCall(
  {
    region: REGION,
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    const name = (request.data as { name?: string })?.name ?? 'World';
    logger.info(`helloWorld called by uid=${uid}, name=${name}`);

    return { message: `Hello, ${name}!` };
  },
);

// ─── onUserCreate (Firestore Trigger) ────────────────────────────────────────
//
// Fires whenever a new document is written to the `users` collection.
// Flutter's FirebaseUserRepository writes this document on first sign-in.
// Use this to initialise server-side state, send a welcome notification, etc.
//
// The document path matches the Firestore security rules in firestore.rules:
//   match /users/{userId} { ... }

export const onUserCreate = onDocumentCreated(
  {
    document: 'users/{userId}',
    region: REGION,
  },
  async (event) => {
    const userId = event.params.userId;
    const data = event.data?.data();

    if (!data) {
      logger.warn(`onUserCreate: empty document for uid=${userId}`);
      return;
    }

    logger.info(`New user created: uid=${userId}`);

    // TODO: add your server-side initialisation here, e.g.:
    //   - send a welcome push notification
    //   - create related documents in other collections
    //   - call an external API

    // Example: stamp a server-side createdAt if the client didn't set one
    if (!data.createdAt) {
      await db.collection('users').doc(userId).update({
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  },
);
