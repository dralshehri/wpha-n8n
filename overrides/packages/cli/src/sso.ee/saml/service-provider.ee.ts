import type { SamlPreferences } from '@n8n/api-types';
import { GlobalConfig } from '@n8n/config';
import { Container } from '@n8n/di';
import { readFileSync } from 'fs';
import type { ServiceProviderInstance } from 'samlify';

import { UrlService } from '@/services/url.service';

let serviceProviderInstance: ServiceProviderInstance | undefined;

export function getServiceProviderEntityId(): string {
	return Container.get(UrlService).getInstanceBaseUrl() + '/rest/sso/saml/metadata';
}

export function getServiceProviderReturnUrl(): string {
	return Container.get(UrlService).getInstanceBaseUrl() + '/rest/sso/saml/acs';
}

export function getServiceProviderConfigTestReturnUrl(): string {
	// TODO: what is this URL?
	return Container.get(UrlService).getInstanceBaseUrl() + '/config/test/return';
}

// TODO:SAML: make these configurable for the end user
export function getServiceProviderInstance(
	prefs: SamlPreferences,
	// eslint-disable-next-line @typescript-eslint/consistent-type-imports
	samlify: typeof import('samlify'),
): ServiceProviderInstance {
	if (serviceProviderInstance === undefined) {
		const config = Container.get(GlobalConfig);
		const spConfig: any = {
			entityID: getServiceProviderEntityId(),
			// Enable signing if the certificate path is provided, otherwise use preferences
			authnRequestsSigned: config.sso.saml.signingCertPath ? true : prefs.authnRequestsSigned,
			wantAssertionsSigned: prefs.wantAssertionsSigned,
			wantMessageSigned: prefs.wantMessageSigned,
			signatureConfig: prefs.signatureConfig,
			relayState: prefs.relayState,
			nameIDFormat: ['urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress'],
			assertionConsumerService: [
				{
					isDefault: prefs.acsBinding === 'post',
					Binding: 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST',
					Location: getServiceProviderReturnUrl(),
				},
				{
					isDefault: prefs.acsBinding === 'redirect',
					Binding: 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-REDIRECT',
					Location: getServiceProviderReturnUrl(),
				},
			],
		};

		// Load SP certificate from file if path is provided
		if (config.sso.saml.signingCertPath) {
			try {
				const certContent = readFileSync(config.sso.saml.signingCertPath, 'utf8');
				// Extract private key and certificate from the combined file
				const privateKeyMatch = certContent.match(/-----BEGIN (?:RSA )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA )?PRIVATE KEY-----/);
				const certMatch = certContent.match(/-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----/);

				if (privateKeyMatch) {
					spConfig.privateKey = privateKeyMatch[0];
				}
				if (certMatch) {
					spConfig.signingCert = certMatch[0];
				}
			} catch (error) {
				console.error(`Failed to load SP certificate from ${config.sso.saml.signingCertPath}:`, error);
			}
		}

		serviceProviderInstance = samlify.ServiceProvider(spConfig);
	}

	return serviceProviderInstance;
}
