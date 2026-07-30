import { IAPHelper } from './iap-helper';

export class PaywallView {
    private iapHelper: IAPHelper;

    constructor() {
        this.iapHelper = new IAPHelper();
    }

    public async purchaseItem(itemID: string): Promise<void> {
        try {
            await this.iapHelper.purchaseItem(itemID);
            // Handle successful purchase
            console.log(`Successfully purchased item ${itemID}`);
        } catch (error) {
            // Handle failed purchase
            console.error(`Failed to purchase item ${itemID}:`, error);
        }
    }

    public async restorePurchases(): Promise<void> {
        try {
            await this.iapHelper.restorePurchases();
            // Handle successful restoration
            console.log('Successfully restored purchases');
        } catch (error) {
            // Handle failed restoration
            console.error('Failed to restore purchases:', error);
        }
    }
}
