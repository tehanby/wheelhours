import { PaywallView } from './purchase';

const paywall = new PaywallView();

async function run() {
    await paywall.purchaseItem('item123');
    await paywall.restorePurchases();
}

run().catch(console.error);
