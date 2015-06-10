////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#ifndef __realm__object_schema__
#define __realm__object_schema__

#include <string>
#include <vector>

#include "property.hpp"
#include <realm/group.hpp>
#include <realm/table.hpp>

namespace realm {
    class ObjectSchema {
    public:
        ObjectSchema() {}

        // create object schema from existing table
        // if no table is provided it is looked up in the group
        ObjectSchema(Group *group, const std::string &name, Table *table = nullptr);

        std::string name;
        std::vector<Property> properties;
        std::string primary_key;

        Property *property_for_name(const std::string &name);
        Property *primary_key_property() {
            return property_for_name(primary_key);
        }
    };
}

#endif /* defined(__realm__object_schema__) */