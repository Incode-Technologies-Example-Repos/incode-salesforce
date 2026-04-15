/**
 * IncodePostInstallTest
 *
 * Verifies the post-install script runs without errors and creates
 * the default Incode_Config__c record.
 */
@IsTest
private class IncodePostInstallTest {

    @IsTest
    static void testOnInstall_CreatesConfigRecord() {
        // Ensure no config exists before installation
        delete [SELECT Id FROM Incode_Config__c];

        Test.startTest();
        IncodePostInstall installer = new IncodePostInstall();
        Test.testInstall(installer, null, false);
        Test.stopTest();

        List<Incode_Config__c> configs = [SELECT Id FROM Incode_Config__c];
        System.assertEquals(1, configs.size(), 'Post-install should create one Incode_Config__c record');
    }

    @IsTest
    static void testOnInstall_ExistingConfig_DoesNotDuplicate() {
        // Pre-existing config
        Incode_Config__c existing = new Incode_Config__c(
            SetupOwnerId      = UserInfo.getOrganizationId(),
            API_Key__c        = 'pre-existing',
            Webhook_Secret__c = 'pre-existing-secret'
        );
        insert existing;

        Test.startTest();
        IncodePostInstall installer = new IncodePostInstall();
        Test.testInstall(installer, null, false);
        Test.stopTest();

        List<Incode_Config__c> configs = [SELECT Id FROM Incode_Config__c];
        System.assertEquals(1, configs.size(), 'Should not create duplicate config records');
    }

    @IsTest
    static void testOnInstall_Upgrade_DoesNotThrow() {
        // Simulate an upgrade (non-null previous version)
        Test.startTest();
        IncodePostInstall installer = new IncodePostInstall();
        Test.testInstall(installer, new Version(1, 0), true);
        Test.stopTest();

        System.assert(true, 'Upgrade install should complete without exception');
    }
}
