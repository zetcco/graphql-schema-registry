import ballerina/test;

@test:Config {
    groups: ["builtin", "directives"],
    dataProvider:  dataProviderBuiltInDirectives
}
function testBuiltInDirectives(__Directive expectedDirective) returns error? {
    string sdl = check getGraphqlSdlFromFile("builtin_scalars");
    Parser parser = new(sdl, SCHEMA);
    __Schema parsedSchema = check parser.parse();
    test:assertEquals(parsedSchema.directives.get(expectedDirective.name), expectedDirective);
}

function dataProviderBuiltInDirectives() returns map<[__Directive]> {
    return { 
        "deprecated"  : [deprecated],
        "skip"        : [skip],
        "include"     : [include],
        "specifiedBy" : [specifiedBy]
    };
}