import ballerina/test;
import graphql_schema_registry.parser;

@test:Config {
    groups: ["merger", "interfaces", "conflict"]
}
function testConflictInterfaceTypeDescription() returns error? {
    string typeName = "Foo";
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("multiple_subgraphs_conflicting_interfaces");
    Supergraph supergraph = check (new Merger(schemas[1])).merge();

    test:assertEquals( supergraph.schema.types.get(typeName).name, schemas[0].types.get(typeName).name);
    test:assertEquals( supergraph.schema.types.get(typeName).description, schemas[0].types.get(typeName).description);
}

@test:Config {
    groups: ["merger", "interfaces", "conflict"],
    dataProvider: dataProviderConflictInterfaceTypesFields
}
function testConflictInterfaceTypeFields(string fieldName) returns error? {
    string typeName = "Foo";
    [parser:__Schema, Subgraph[]] schemas = check getSchemas("multiple_subgraphs_conflicting_interfaces");
    Supergraph supergraph = check (new Merger(schemas[1])).merge();

    map<parser:__Field>? actualFields = supergraph.schema.types.get(typeName).fields;
    map<parser:__Field>? expectedFields = schemas[0].types.get(typeName).fields;
    if actualFields is map<parser:__Field> && expectedFields is map<parser:__Field> {
        test:assertEquals(
            actualFields.get(fieldName),
            expectedFields.get(fieldName)
        );
    } else {
        test:assertFail(string `Cannot find field on '${typeName}' '${fieldName}'`);
    }
}

function dataProviderConflictInterfaceTypesFields() returns [string][] {
    return [
        ["name"],
        ["age"],
        ["avg"],
        ["isStudent"],
        ["isBux"]
    ];
}