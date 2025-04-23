import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.2/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
    name: "EcoWeave: Project Creation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        const block = chain.mineBlock([
            Tx.contractCall('ecoweave', 'create-project', [
                types.utf8('City Park Cleanup'),
                types.uint(Math.floor(Date.now() / 1000) + 86400), // 24 hours in future
                types.uint(10),          // Required participants
                types.uint(50)           // Reward per participant
            ], deployer.address)
        ]);

        block.receipts[0].result.expectOk();
    }
});

Clarinet.test({
    name: "EcoWeave: Project Registration",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // First create a project
        let block = chain.mineBlock([
            Tx.contractCall('ecoweave', 'create-project', [
                types.utf8('Beach Cleanup'),
                types.uint(Math.floor(Date.now() / 1000) + 86400),
                types.uint(5),           // Required participants
                types.uint(100)          // Reward per participant
            ], deployer.address)
        ]);

        // Get the project ID from the result
        const projectId = block.receipts[0].result.expectOk().toString();

        // Register for the project
        block = chain.mineBlock([
            Tx.contractCall('ecoweave', 'register-for-project', [
                types.uint(parseInt(projectId))
            ], wallet1.address)
        ]);

        block.receipts[0].result.expectOk();
    }
});

Clarinet.test({
    name: "EcoWeave: Proof Submission and Validation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        // Create project
        let block = chain.mineBlock([
            Tx.contractCall('ecoweave', 'create-project', [
                types.utf8('Forest Trail Cleanup'),
                types.uint(Math.floor(Date.now() / 1000) + 86400),
                types.uint(3),           // Required participants
                types.uint(200)          // Reward per participant
            ], deployer.address)
        ]);

        const projectId = block.receipts[0].result.expectOk().toString();

        // Register participants
        block = chain.mineBlock([
            Tx.contractCall('ecoweave', 'register-for-project', [
                types.uint(parseInt(projectId))
            ], wallet1.address),
            Tx.contractCall('ecoweave', 'register-for-project', [
                types.uint(parseInt(projectId))
            ], wallet2.address)
        ]);

        // Submit proof
        block = chain.mineBlock([
            Tx.contractCall('ecoweave', 'submit-project-proof', [
                types.uint(parseInt(projectId)),
                types.utf8('https://example.com/proof.jpg')
            ], wallet1.address)
        ]);

        block.receipts[0].result.expectOk();

        // Validate proof
        block = chain.mineBlock([
            Tx.contractCall('ecoweave', 'validate-project-proof', [
                types.uint(parseInt(projectId)),
                types.principal(wallet1.address),
                types.bool(true)
            ], deployer.address)
        ]);

        block.receipts[0].result.expectOk();
    }
});