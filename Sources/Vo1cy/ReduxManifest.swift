// Pinned Core ML artifacts. Hashes include all graph, weight and vocabulary files.
// Source: https://huggingface.co/FluidInference/parakeet-redux-coreml
enum ReduxManifest {
    static let revision = "8c5ef97a29cd120dc76b354b3f22b7fec3b486f9"
    static let files: [ModelArtifact] = [
        .init(path: "Decoder.mlmodelc/analytics/coremldata.bin", hash: "7f24e7248d57024c6f1c5a2ea306f4a6a89db45a363218523bb6410c4b1aecf0", bytes: 243),
        .init(path: "Decoder.mlmodelc/coremldata.bin", hash: "422da51d983e93a3e48cd6d46a17d6c32844452414c8e242fb0caaca2b8af5ed", bytes: 560),
        .init(path: "Decoder.mlmodelc/model.mil", hash: "956f600207f88396017ca5c96cfa3acd5bfee60835a5b44b762e033a8fb28955", bytes: 13110),
        .init(path: "Decoder.mlmodelc/weights/weight.bin", hash: "6c6c88c23ee5492a6b229e8cc636ddadb2b01ae0dd559d9cb63123bebf507d77", bytes: 23604992),
        .init(path: "Encoder.mlmodelc/analytics/coremldata.bin", hash: "7862e972e09315df099d4bfd320743bf106acbf7fe4343317f9de45b0635d7b7", bytes: 243),
        .init(path: "Encoder.mlmodelc/coremldata.bin", hash: "ca0b212fe3c06c3ccd35e508fa61e4dfaad19dd0c55b82e4f5bf8711e7758fd9", bytes: 506),
        .init(path: "Encoder.mlmodelc/model.mil", hash: "165487e314ed93c4a44dfec99d57be4e436e7c3dba6eef49fd3f0daf9de6d0d4", bytes: 965906),
        .init(path: "Encoder.mlmodelc/weights/weight.bin", hash: "adbb5550dc6488717d3a1407b53122fbdb1af5e99c330ee20f8d8cfd9ec49252", bytes: 182389312),
        .init(path: "JointDecisionv3.mlmodelc/analytics/coremldata.bin", hash: "fc857a756b8c9c9f31aa9e1062766cc0a82ac035ef369d6e1cbe97184921479c", bytes: 243),
        .init(path: "JointDecisionv3.mlmodelc/coremldata.bin", hash: "611ea653e2adede7cc1cfe70da36296844f97e95e2c7dd961d45230e5599389d", bytes: 592),
        .init(path: "JointDecisionv3.mlmodelc/model.mil", hash: "791b3c3cf3eb2079c84623fc880f6bba008d1366e5f8b03e9a8ed8bd4d7194a0", bytes: 11777),
        .init(path: "JointDecisionv3.mlmodelc/weights/weight.bin", hash: "73b0288acd115fc4c36038f66b6cbf49233182488febf5d8c787bea4009535f7", bytes: 12642764),
        .init(path: "Preprocessor.mlmodelc/analytics/coremldata.bin", hash: "c9beeb989c8d66f8be11df59bc6df277ec76cee404f6865b46243835ef562f6d", bytes: 243),
        .init(path: "Preprocessor.mlmodelc/coremldata.bin", hash: "dbde3f2300842c1fd51ef3ff948a0bcffe65ffd2dca10707f2509f32c1d65b1d", bytes: 486),
        .init(path: "Preprocessor.mlmodelc/metadata.json", hash: "2a98699e22d279dd37fa1d238aeb1c6db1df0d6fad687775324157689d8f3acf", bytes: 2841),
        .init(path: "Preprocessor.mlmodelc/model.mil", hash: "4b8518a956450fec57f06c2a21bdffc26973f7f1fa6842fb38fe917f896b6b93", bytes: 28181),
        .init(path: "Preprocessor.mlmodelc/weights/weight.bin", hash: "129b76e3aeafa8afa3ea76d995b964b145fe83700d579f6ff42c4c38fa0968ea", bytes: 491072),
        .init(path: "parakeet_vocab.json", hash: "7ec60e05f1b24480736ec0eed40900f4626bce1fa9a60fd700ec7e2a59198735", bytes: 151122),
    ]
}
