import ballerina/graphql;
import graphql_schema_registry.registry;
import graphql_schema_registry.datasource;

isolated service / on new graphql:Listener(9090) {

    private final registry:Registry registry;
    

    public function init() returns error? {
        datasource:Datasource datasource = check new FileDatasource("datasource");
        // datasource:Datasource datasource = new InMemoryDatasource();
        self.registry = new(datasource);
    }

    isolated resource function get supergraph() returns Supergraph|error {
        return new Supergraph(check self.registry.getLatestSupergraph());
    }

    isolated resource function get dryRun(SubgraphInput schema) returns Supergraph|error {
        return new Supergraph(check self.registry.dryRun(schema));
    }

    // resource function get subgraph(string name) returns Subgraph|error {
    //     return new Subgraph(check self.registry.getSubgraphByName(name));
    // }

    isolated remote function publishSubgraph(SubgraphInput schema) returns Supergraph|error {
        return new Supergraph(check self.registry.publishSubgraph(schema));
    }
}
