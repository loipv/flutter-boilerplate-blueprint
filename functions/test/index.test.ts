import * as admin from 'firebase-admin';
import { HttpsError } from 'firebase-functions/v2/https';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { helloWorld, onUserCreate } from '../src/index';

// Runs inside `firebase emulators:exec`, which sets FIRESTORE_EMULATOR_HOST and
// GCLOUD_PROJECT=demo-test, so the `admin.initializeApp()` in src/index.ts
// targets the local emulator. Each v2 function exposes its handler as `.run()`,
// so no functions or auth emulator is needed.
const db = admin.firestore();

beforeAll(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error('Run these tests with `make test-firebase` (needs the Firestore emulator).');
  }
});

beforeEach(async () => {
  await db.recursiveDelete(db.collection('users'));
});

afterAll(async () => {
  await admin.app().delete();
});

describe('helloWorld', () => {
  it('Given no auth, When called, Then it rejects with unauthenticated', async () => {
    const call = helloWorld.run({ auth: undefined, data: {} } as any);

    await expect(call).rejects.toBeInstanceOf(HttpsError);
    await expect(call).rejects.toMatchObject({ code: 'unauthenticated' });
  });

  it('Given auth and a name, When called, Then it greets the name', async () => {
    const result = await helloWorld.run({ auth: { uid: 'u1' }, data: { name: 'Ada' } } as any);

    expect(result).toEqual({ message: 'Hello, Ada!' });
  });

  it('Given auth and no name, When called, Then it greets World', async () => {
    const result = await helloWorld.run({ auth: { uid: 'u1' }, data: {} } as any);

    expect(result).toEqual({ message: 'Hello, World!' });
  });
});

describe('onUserCreate', () => {
  it('Given a user without createdAt, When triggered, Then it stamps createdAt', async () => {
    const ref = db.doc('users/u1');
    await ref.set({ name: 'x' });
    const snap = await ref.get();

    await onUserCreate.run({ params: { userId: 'u1' }, data: snap } as any);

    const after = (await ref.get()).data();
    expect(after?.name).toBe('x');
    expect(after?.createdAt).toBeInstanceOf(admin.firestore.Timestamp);
  });

  it('Given a user with createdAt, When triggered, Then it keeps createdAt', async () => {
    const ref = db.doc('users/u1');
    await ref.set({ name: 'x', createdAt: 'keep' });
    const snap = await ref.get();

    await onUserCreate.run({ params: { userId: 'u1' }, data: snap } as any);

    expect((await ref.get()).data()?.createdAt).toBe('keep');
  });

  it('Given no document data, When triggered, Then it resolves and writes nothing', async () => {
    await expect(
      onUserCreate.run({ params: { userId: 'u1' }, data: undefined } as any),
    ).resolves.toBeUndefined();

    expect((await db.doc('users/u1').get()).exists).toBe(false);
  });
});
