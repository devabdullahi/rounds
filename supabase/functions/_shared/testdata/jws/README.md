Throwaway certificate chain for `appstorejws_test.ts`, made with openssl. Not Apple's and not trusted
anywhere: the root is passed to the verifier explicitly in tests. `leaf.p8.pem` is the test leaf's
private key, used only to sign test JWS strings. Shape matches Apple's: P-384 root and intermediate
(intermediate carries OID 1.2.840.113635.100.6.2.1), P-256 leaf (OID 1.2.840.113635.100.6.11.1);
`leaf-nooid.pem` lacks the leaf OID.
