import { readFileSync } from 'node:fs';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { getMetadata, ref, uploadBytes } from 'firebase/storage';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';

// Runs inside `firebase emulators:exec`, which sets FIREBASE_STORAGE_EMULATOR_HOST.
let testEnv: RulesTestEnvironment;

const png = new Uint8Array([0x89, 0x50, 0x4e, 0x47]);
const meta = { contentType: 'image/png' };

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-test',
    storage: {
      rules: readFileSync(new URL('../storage.rules', import.meta.url), 'utf8'),
    },
  });
});

afterAll(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearStorage();
});

/** Uploads [path] with the rules off, so read tests have a file to read. */
async function seed(path: string): Promise<void> {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(ref(ctx.storage(), path), png, meta);
  });
}

describe('users/{userId}/**', () => {
  it('Given alice, When she uploads to or reads users/alice/a.png, Then it succeeds', async () => {
    const storage = testEnv.authenticatedContext('alice').storage();
    const file = ref(storage, 'users/alice/a.png');

    await assertSucceeds(uploadBytes(file, png, meta));
    await assertSucceeds(getMetadata(file));
  });

  it('Given bob, When he accesses users/alice/a.png, Then it fails', async () => {
    await seed('users/alice/a.png');
    const storage = testEnv.authenticatedContext('bob').storage();
    const file = ref(storage, 'users/alice/a.png');

    await assertFails(getMetadata(file));
    await assertFails(uploadBytes(file, png, meta));
  });
});

describe('public/**', () => {
  it('Given alice, When she reads public/a.png, Then it succeeds', async () => {
    await seed('public/a.png');
    const storage = testEnv.authenticatedContext('alice').storage();

    await assertSucceeds(getMetadata(ref(storage, 'public/a.png')));
  });

  it('Given unauthenticated, When reading public/a.png, Then it fails', async () => {
    await seed('public/a.png');
    const storage = testEnv.unauthenticatedContext().storage();

    await assertFails(getMetadata(ref(storage, 'public/a.png')));
  });

  it('Given alice, When she writes public/a.png, Then it fails', async () => {
    const storage = testEnv.authenticatedContext('alice').storage();

    await assertFails(uploadBytes(ref(storage, 'public/a.png'), png, meta));
  });
});
