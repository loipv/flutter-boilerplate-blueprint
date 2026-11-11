import { readFileSync } from 'node:fs';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';

// Runs inside `firebase emulators:exec`, which sets FIRESTORE_EMULATOR_HOST.
let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-test',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

afterAll(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe('users/{userId}', () => {
  it('Given alice, When she reads or writes users/alice, Then it succeeds', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();

    await assertSucceeds(setDoc(doc(db, 'users/alice'), { name: 'Alice' }));
    await assertSucceeds(getDoc(doc(db, 'users/alice')));
  });

  it('Given bob, When he reads or writes users/alice, Then it fails', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'users/alice'), { name: 'Alice' });
    });
    const db = testEnv.authenticatedContext('bob').firestore();

    await assertFails(getDoc(doc(db, 'users/alice')));
    await assertFails(setDoc(doc(db, 'users/alice'), { name: 'Bob' }));
  });

  it('Given unauthenticated, When reading users/alice, Then it fails', async () => {
    const db = testEnv.unauthenticatedContext().firestore();

    await assertFails(getDoc(doc(db, 'users/alice')));
  });
});

describe('other collections', () => {
  it('Given alice, When she writes items/x, Then it fails', async () => {
    const db = testEnv.authenticatedContext('alice').firestore();

    await assertFails(setDoc(doc(db, 'items/x'), { name: 'x' }));
  });
});
