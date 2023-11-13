import graphql_schema_registry.parser;

class Exporter {

    private parser:__Schema schema;

    function init(parser:__Schema schema) {
        self.schema = schema;
    }
    
    function export() returns string|ExportError {
        string directives = check self.exportDirectives();
        string types = check self.exportTypes();
        return directives + DOUBLE_LINE_BREAK + types;
    }

    function exportTypes() returns string|ExportError {
        string[] typeSdls = [];
        string[] sortedTypeNames = self.schema.types.keys().sort();
        foreach string typeName in sortedTypeNames {
            parser:__Type 'type = self.schema.types.get(typeName);
            if parser:isBuiltInType(typeName) {
                continue;
            }

            match 'type.kind {
                parser:OBJECT => { typeSdls.push(check self.exportObjectType('type)); }
                // parser:INTERFACE => { typeSdls.push(self.exportInterfaceType('type)); }
                // parser:INPUT_OBJECT => { typeSdls.push(self.exportInputObjectType('type)); }
                // parser:ENUM => { typeSdls.push(self.exportEnumType('type)); }
            }
        }

        return string:'join(DOUBLE_LINE_BREAK, ...typeSdls);
    }

    function exportObjectType(parser:__Type 'type) returns string|ExportError {
        string? typeName = 'type.name;
        if typeName is () {
            return error ExportError("Type name cannot be null");
        }
        map<parser:__Field>? fields = 'type.fields;
        if fields is () {
            return error ExportError("Object field map cannot be null");
        }

        string? description = 'type.description;
        string descriptionSdl = EMPTY_STRING;
        if description is string {
            descriptionSdl = self.exportDescription(description) + LINE_BREAK;
        }

        string fieldMapSdl = self.addBraces(LINE_BREAK + check self.exportFieldMap(fields) + LINE_BREAK);

        return descriptionSdl + OBJECT_TYPE + SPACE + typeName + SPACE + fieldMapSdl;
    }

    function exportFieldMap(map<parser:__Field> fieldMap, int indentation = 1) returns string|ExportError {
        string[] fields = [];
        boolean isFirstInBlock = true;
        foreach parser:__Field 'field in fieldMap {
            fields.push(check self.exportField('field, isFirstInBlock, indentation));
        
            if isFirstInBlock {
                isFirstInBlock = false;
            }
        }

        return string:'join(LINE_BREAK, ...fields);
    }

    function exportField(parser:__Field 'field, boolean isFirstInBlock, int indentation) returns string|ExportError {
        string typeReferenceSdl = check self.exportTypeReference('field.'type);

        string? description = 'field.description;
        string descriptionSdl = EMPTY_STRING;
        if description is string {
            descriptionSdl = isFirstInBlock ? EMPTY_STRING : LINE_BREAK;
            descriptionSdl += self.addIndentation(indentation) + self.exportDescription(description) + LINE_BREAK;
        }

        string argsSdl = EMPTY_STRING;
        map<parser:__InputValue> args = 'field.args;
        if args != {} {
            if args.toArray().some(i => i.description is string) {
                argsSdl = check self.exportInputValues('field.args, LINE_BREAK, indentation + 1);
                argsSdl = LINE_BREAK + argsSdl + LINE_BREAK + self.addIndentation(indentation);
            } else {
                argsSdl = check self.exportInputValues('field.args, COMMA + SPACE);
            }
            argsSdl = self.addParantheses(argsSdl);
        }

        return descriptionSdl + self.addIndentation(indentation) + 'field.name + argsSdl + COLON + SPACE + typeReferenceSdl;
    }

    function exportDirectives() returns string|ExportError {
        string[] directives = [];
        foreach parser:__Directive directive in self.schema.directives {
            if parser:isBuiltInDirective(directive.name) {
                continue;
            }
            directives.push(check self.exportDirective(directive));
        }
        directives = directives.sort();
        return string:'join(DOUBLE_LINE_BREAK, ...directives);
    }

    function exportDirective(parser:__Directive directive) returns string|ExportError {
        string directiveDefinitionSdl = string `directive @${directive.name}`;
        string directiveArgsSdl = self.addParantheses(check self.exportInputValues(directive.args, COMMA + SPACE));
        string repeatableSdl = directive.isRepeatable ? REPEATABLE + SPACE : EMPTY_STRING;
        string directiveLocations = ON + SPACE + string:'join(SPACE + PIPE + SPACE, ...directive.locations);

        return directiveDefinitionSdl + directiveArgsSdl + SPACE + repeatableSdl + directiveLocations;
    }

    function exportInputValues(map<parser:__InputValue> args, string seperator, int indentation = 0) returns string|ExportError {
        string[] argSdls = [];
        
        boolean isFirstInBlock = args.toArray().some(i => i.description is string);
        foreach parser:__InputValue arg in args {
            argSdls.push(check self.exportInputValue(arg, isFirstInBlock, indentation));

            if isFirstInBlock {
                isFirstInBlock = false;
            }
        }
        return string:'join(seperator, ...argSdls);
    }

    function exportInputValue(parser:__InputValue arg, boolean isFirstInBlock, int indentation = 0) returns string|ExportError {
        string typeReferenceSdl = check self.exportTypeReference(arg.'type);

        string? description = arg.description;
        string descriptionSdl = EMPTY_STRING;
        if description is string {
            descriptionSdl = isFirstInBlock ? EMPTY_STRING : LINE_BREAK;
            descriptionSdl += self.addIndentation(indentation) + self.exportDescription(description) + LINE_BREAK;
        }

        string defaultValueSdl = self.exportDefaultValue(arg.defaultValue);
        return descriptionSdl + self.addIndentation(indentation) +  arg.name + COLON + SPACE + typeReferenceSdl + defaultValueSdl;
    }

    function exportDefaultValue(anydata? defaultValue) returns string {
        if defaultValue is () {
            return EMPTY_STRING;
        } else {
            return SPACE + EQUAL + SPACE + self.exportValue(defaultValue);
        }
    }

    function exportValue(anydata input) returns string {
        if input is string {
            return string `"${input}"`;
        } else if input is int|float|boolean {
            return input.toBalString();
        } else if input is parser:__EnumValue {
            return input.name;
        } else {
            return "<UNKNOWN_TYPE>";
        }
    }

    function exportDescription(string description) returns string {
        return string `"""${description}"""`;
    }

    function exportTypeReference(parser:__Type 'type) returns string|ExportError {
        string? typeName = 'type.name;
        if 'type.kind == parser:LIST {
            return self.addSquareBrackets(check self.exportTypeReference(<parser:__Type>'type.ofType));
        } else if 'type.kind == parser:NON_NULL {
            return check self.exportTypeReference(<parser:__Type>'type.ofType) + EXCLAMATION;
        } else if typeName is string {
            return typeName;
        } else {
            return error ExportError("Invalid type reference");
        }
    }

    function addBraces(string input) returns string {
        return string `{${input}}`;
    }

    function addParantheses(string input) returns string {
        return string `(${input})`;
    }

    function addSquareBrackets(string input) returns string {
        return string `[${input}]`;
    }

    function addIndentation(int level) returns string {
        string indentation = EMPTY_STRING;
        foreach int i in 0...level-1 {
            indentation += INDENTATION;
        }
        return indentation;
    }

}