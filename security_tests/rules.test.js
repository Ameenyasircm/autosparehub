// Firestore security rules tests. Run from this folder:  npm test
// (starts the Firestore emulator; needs Java and the Firebase CLI).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection, deleteDoc, doc, getDoc, getDocs, query, setDoc, updateDoc, where, deleteField,
} from 'firebase/firestore';

const PHONE = '9876543210';
const OTHER = '9123456789';
const USER_ID = `USR_91${PHONE}`;
const OTHER_ID = `USR_91${OTHER}`;

let env;

const customer = (uid = 'cust-uid', phone = PHONE, suffix = '') =>
  env.authenticatedContext(uid, { email: `c${phone}${suffix}@autosparehub.app` }).firestore();
const admin = (uid = 'staff-uid') =>
  env.authenticatedContext(uid, { email: `aad1${suffix(uid)}@autosparehub.app` }).firestore();
const suffix = (s) => s.replace(/[^a-z0-9]/g, '');
const anon = () => env.unauthenticatedContext().firestore();

const newUser = (overrides = {}) => ({
  ID: USER_ID, NAME: 'Garage', PHONE_NUMBER: PHONE, STATUS: 'PENDING',
  AUTH_UID: 'cust-uid', REQUESTED_AT: new Date(), APPROVED_AT: null,
  REJECTION_REASON: null, UPDATED_AT: new Date(),
  NORMALIZED_PHONE: `91${PHONE}`, DISPLAY_PHONE: '98765 43210',
  ...overrides,
});

const newOrder = (overrides = {}) => ({
  ID: 'ORD1', ORDER_NUMBER: '#ORD-0001', USER_ID, USER_NAME: 'Garage',
  USER_PHONE: PHONE, PRODUCT_ID: 'P1', PRODUCT_NAME: 'Pump', PRODUCT_IMAGE: '',
  COMPANY_NAME: 'BOSCH', CATEGORY_NAME: 'Steering', UNIT_PRICE: 100,
  QUANTITY: 1, TOTAL_AMOUNT: 100, SHIPPING_ADDRESS: null, CUSTOMER_NOTE: null,
  ADMIN_REMARK: null, STATUS: 'PENDING', ITEMS: [{ PRODUCT_ID: 'P1', QUANTITY: 1 }],
  CATEGORY_NAMES: ['Steering'], CREATED_AT: new Date(), UPDATED_AT: new Date(),
  ...overrides,
});

// Seeds data bypassing the rules.
async function seed(fn) {
  await env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-autosparehub',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seed(async (db) => {
    await setDoc(doc(db, 'ROLES/staff-uid'), { ADMIN_ID: 'AD1', ROLE: 'STAFF', IS_ACTIVE: true });
    await setDoc(doc(db, 'ROLES/manager-uid'), { ADMIN_ID: 'AD2', ROLE: 'MANAGER', IS_ACTIVE: true });
    await setDoc(doc(db, 'ROLES/inactive-uid'), { ADMIN_ID: 'AD3', ROLE: 'MANAGER', IS_ACTIVE: false });
    await setDoc(doc(db, 'ADMINS/AD1'), { NAME: 'Staff', PHONE_NUMBER: '111', TYPE: 'STAFF', IS_ACTIVE: true, AUTH_UID: 'staff-uid' });
    await setDoc(doc(db, 'ADMINS/AD2'), { NAME: 'Boss', PHONE_NUMBER: '222', TYPE: 'MANAGER', IS_ACTIVE: true, AUTH_UID: 'manager-uid' });
    await setDoc(doc(db, 'ADMINS/AD3'), { NAME: 'Old', PHONE_NUMBER: '333', TYPE: 'MANAGER', IS_ACTIVE: false, AUTH_UID: 'inactive-uid' });
    await setDoc(doc(db, `USERS/${OTHER_ID}`), newUser({ ID: OTHER_ID, PHONE_NUMBER: OTHER, AUTH_UID: 'other-uid', STATUS: 'APPROVED' }));
    await setDoc(doc(db, 'PRODUCTS/P1'), { NAME: 'Pump', PRICE: 100 });
    await setDoc(doc(db, 'LOGIN_INDEX/A222'), { EMAIL: 'aad2@autosparehub.app' });
    await setDoc(doc(db, `ORDERS/ORD_OTHER`), newOrder({ ID: 'ORD_OTHER', USER_ID: OTHER_ID, USER_PHONE: OTHER }));
  });
});

const approveMe = () => seed((db) => setDoc(doc(db, `USERS/${USER_ID}`), newUser({ STATUS: 'APPROVED' })));
const pendingMe = () => seed((db) => setDoc(doc(db, `USERS/${USER_ID}`), newUser()));

describe('anonymous (anyone holding the public API key)', () => {
  test('can browse the catalogue and look up one login key', async () => {
    await assertSucceeds(getDoc(doc(anon(), 'PRODUCTS/P1')));
    await assertSucceeds(getDoc(doc(anon(), 'LOGIN_INDEX/A222')));
  });
  test('cannot dump customers, admins, roles, orders or login keys', async () => {
    await assertFails(getDocs(collection(anon(), 'USERS')));
    await assertFails(getDoc(doc(anon(), `USERS/${OTHER_ID}`)));
    await assertFails(getDocs(collection(anon(), 'ADMINS')));
    await assertFails(getDocs(collection(anon(), 'ROLES')));
    await assertFails(getDocs(collection(anon(), 'ORDERS')));
    await assertFails(getDocs(collection(anon(), 'LOGIN_INDEX')));
  });
  test('cannot write anything', async () => {
    await assertFails(setDoc(doc(anon(), 'PRODUCTS/P1'), { PRICE: 1 }));
    await assertFails(setDoc(doc(anon(), 'ROLES/hacker'), { ADMIN_ID: 'X', ROLE: 'MANAGER', IS_ACTIVE: true }));
    await assertFails(setDoc(doc(anon(), 'LOGIN_INDEX/A222'), { EMAIL: 'evil@x.com' }));
    await assertFails(setDoc(doc(anon(), 'RANDOM/x'), { a: 1 }));
  });
});

describe('customer self-registration', () => {
  test('can create own PENDING record and login key', async () => {
    const db = customer();
    await assertSucceeds(getDoc(doc(db, `USERS/${USER_ID}`))); // not yet existing
    await assertSucceeds(setDoc(doc(db, `USERS/${USER_ID}`), newUser()));
    await assertSucceeds(setDoc(doc(db, `LOGIN_INDEX/C91${PHONE}`), { EMAIL: `c${PHONE}@autosparehub.app`, UPDATED_AT: new Date() }));
  });
  test('cannot self-approve, store a password, or register another number', async () => {
    const db = customer();
    await assertFails(setDoc(doc(db, `USERS/${USER_ID}`), newUser({ STATUS: 'APPROVED' })));
    await assertFails(setDoc(doc(db, `USERS/${USER_ID}`), newUser({ PASSWORD: 'secret' })));
    await assertFails(setDoc(doc(db, `USERS/${USER_ID}`), newUser({ AUTH_UID: 'someone-else' })));
    await assertFails(setDoc(doc(db, `USERS/USR_91${OTHER}`), newUser({ ID: `USR_91${OTHER}`, PHONE_NUMBER: OTHER })));
    await assertFails(setDoc(doc(db, `LOGIN_INDEX/C91${OTHER}`), { EMAIL: `c${PHONE}@autosparehub.app` }));
    await assertFails(setDoc(doc(db, 'LOGIN_INDEX/A222'), { EMAIL: `c${PHONE}@autosparehub.app` }));
  });
  test('cannot take over an existing record', async () => {
    await assertFails(setDoc(doc(customer('attacker', OTHER), `USERS/${OTHER_ID}`),
      newUser({ ID: OTHER_ID, PHONE_NUMBER: OTHER, AUTH_UID: 'attacker' })));
  });
});

describe('signed-in customer', () => {
  test('reads own record only', async () => {
    await pendingMe();
    await assertSucceeds(getDoc(doc(customer(), `USERS/${USER_ID}`)));
    await assertFails(getDoc(doc(customer(), `USERS/${OTHER_ID}`)));
    await assertFails(getDocs(collection(customer(), 'USERS')));
  });
  test('can update push token and re-apply, but not approve itself', async () => {
    await pendingMe();
    const db = customer();
    await assertSucceeds(updateDoc(doc(db, `USERS/${USER_ID}`), { FCM_TOKEN: 't', FCM_UPDATED_AT: new Date() }));
    await assertFails(updateDoc(doc(db, `USERS/${USER_ID}`), { STATUS: 'APPROVED' }));
    await assertFails(updateDoc(doc(db, `USERS/${USER_ID}`), { NAME: 'x', FCM_TOKEN: 't2' }));
    await seed((s) => updateDoc(doc(s, `USERS/${USER_ID}`), { STATUS: 'REJECTED' }));
    await assertSucceeds(updateDoc(doc(db, `USERS/${USER_ID}`),
      { STATUS: 'PENDING', REQUESTED_AT: new Date(), REJECTION_REASON: null, UPDATED_AT: new Date() }));
  });
  test('old sign-in stops working after an admin password reset', async () => {
    await approveMe();
    await seed((s) => updateDoc(doc(s, `USERS/${USER_ID}`), { AUTH_UID: 'new-uid' }));
    await assertFails(getDoc(doc(customer('cust-uid'), `USERS/${USER_ID}`)));
    await assertFails(setDoc(doc(customer('cust-uid'), 'ORDERS/ORD1'), newOrder()));
    await assertSucceeds(getDoc(doc(customer('new-uid', PHONE, '_123'), `USERS/${USER_ID}`)));
  });
  test('cart is private', async () => {
    await approveMe();
    await assertSucceeds(setDoc(doc(customer(), `CARTS/${USER_ID}`), { USER_ID, ITEMS: [] }));
    await assertFails(getDoc(doc(customer(), `CARTS/${OTHER_ID}`)));
    await assertFails(setDoc(doc(customer(), `CARTS/${OTHER_ID}`), { ITEMS: [] }));
  });
  test('cannot touch catalogue, admins, roles or back office', async () => {
    await approveMe();
    const db = customer();
    await assertFails(updateDoc(doc(db, 'PRODUCTS/P1'), { PRICE: 1 }));
    await assertFails(getDocs(collection(db, 'ADMINS')));
    await assertFails(setDoc(doc(db, 'ROLES/cust-uid'), { ADMIN_ID: 'X', ROLE: 'MANAGER', IS_ACTIVE: true }));
    await assertFails(getDocs(collection(db, 'SALES')));
    await assertFails(getDocs(collection(db, 'NOTIFICATIONS')));
  });
});

describe('orders', () => {
  test('pending customer cannot order; approved customer can, for itself only', async () => {
    await pendingMe();
    await assertFails(setDoc(doc(customer(), 'ORDERS/ORD1'), newOrder()));
    await approveMe();
    await assertSucceeds(setDoc(doc(customer(), 'ORDERS/ORD1'), newOrder()));
    await assertFails(setDoc(doc(customer(), 'ORDERS/ORD2'), newOrder({ ID: 'ORD2', USER_ID: OTHER_ID })));
    await assertFails(setDoc(doc(customer(), 'ORDERS/ORD3'), newOrder({ ID: 'ORD3', STATUS: 'DELIVERED' })));
    await assertFails(setDoc(doc(customer(), 'ORDERS/ORD4'), newOrder({ ID: 'ORD4', ADMIN_REMARK: 'ok' })));
  });
  test('customer sees own orders only and cannot change status', async () => {
    await approveMe();
    const db = customer();
    await assertSucceeds(setDoc(doc(db, 'ORDERS/ORD1'), newOrder()));
    await assertSucceeds(getDocs(query(collection(db, 'ORDERS'), where('USER_ID', '==', USER_ID))));
    await assertSucceeds(getDocs(query(collection(db, 'ORDERS'), where('USER_PHONE', '==', PHONE))));
    await assertFails(getDocs(collection(db, 'ORDERS')));
    await assertFails(getDoc(doc(db, 'ORDERS/ORD_OTHER')));
    await assertFails(updateDoc(doc(db, 'ORDERS/ORD1'), { STATUS: 'CONFIRMED' }));
  });
  test('customer can raise an admin alert but not read alerts', async () => {
    await approveMe();
    await assertSucceeds(setDoc(doc(customer(), 'NOTIFICATIONS/N1'), { RECIPIENT_TYPE: 'ADMIN', TITLE: 'x' }));
    await assertFails(setDoc(doc(customer(), 'NOTIFICATIONS/N2'), { RECIPIENT_TYPE: 'USER', TITLE: 'x' }));
  });
});

describe('admins', () => {
  test('staff manage customers, orders and catalogue', async () => {
    await pendingMe();
    const db = admin('staff-uid');
    await assertSucceeds(getDocs(collection(db, 'USERS')));
    await assertSucceeds(updateDoc(doc(db, `USERS/${USER_ID}`), { STATUS: 'APPROVED' }));
    await assertSucceeds(updateDoc(doc(db, 'ORDERS/ORD_OTHER'), { STATUS: 'CONFIRMED' }));
    await assertSucceeds(updateDoc(doc(db, 'PRODUCTS/P1'), { PRICE: 120 }));
    await assertSucceeds(setDoc(doc(db, 'SALES/S1/ITEMS/P1'), { QTY: 1 }));
    await assertSucceeds(setDoc(doc(db, `LOGIN_INDEX/C91${PHONE}`), { EMAIL: 'c@autosparehub.app' }));
  });
  test('staff cannot manage admins or roles, nor set passwords', async () => {
    const db = admin('staff-uid');
    await assertFails(setDoc(doc(db, 'ROLES/staff-uid'), { ADMIN_ID: 'AD1', ROLE: 'MANAGER', IS_ACTIVE: true }));
    await assertFails(updateDoc(doc(db, 'ADMINS/AD1'), { TYPE: 'MANAGER' }));
    await assertFails(setDoc(doc(db, 'LOGIN_INDEX/A222'), { EMAIL: 'evil@autosparehub.app' }));
    await assertFails(updateDoc(doc(db, `USERS/${OTHER_ID}`), { PASSWORD: 'x' }));
    await assertSucceeds(updateDoc(doc(db, 'ADMINS/AD1'), { FCM_TOKEN: 't', FCM_UPDATED_AT: new Date() }));
  });
  test('manager manages admins and roles', async () => {
    const db = admin('manager-uid');
    await assertSucceeds(setDoc(doc(db, 'ADMINS/AD9'), { NAME: 'New', TYPE: 'STAFF', IS_ACTIVE: true }));
    await assertSucceeds(setDoc(doc(db, 'ROLES/new-uid'), { ADMIN_ID: 'AD9', ROLE: 'STAFF', IS_ACTIVE: true }));
    await assertSucceeds(setDoc(doc(db, 'LOGIN_INDEX/A999'), { EMAIL: 'aad9@autosparehub.app' }));
    await assertFails(setDoc(doc(db, 'ADMINS/AD8'), { NAME: 'New', PASSWORD: 'plain' }));
    await assertSucceeds(updateDoc(doc(db, 'ADMINS/AD1'), { PASSWORD: deleteField() }));
  });
  test('deactivated admin loses access but can read own record', async () => {
    const db = admin('inactive-uid');
    await assertFails(getDocs(collection(db, 'USERS')));
    await assertFails(updateDoc(doc(db, 'PRODUCTS/P1'), { PRICE: 1 }));
    await assertSucceeds(getDoc(doc(db, 'ADMINS/AD3')));
    await assertFails(getDoc(doc(db, 'ADMINS/AD1')));
  });
  test('a customer account is never an admin', async () => {
    await approveMe();
    await assertFails(getDocs(collection(customer(), 'ADMINS')));
    await assertFails(deleteDoc(doc(customer(), 'ORDERS/ORD_OTHER')));
  });
});
