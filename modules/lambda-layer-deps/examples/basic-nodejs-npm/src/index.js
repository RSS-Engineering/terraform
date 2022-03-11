const {faker} = require('@faker-js/faker');

const lambda_handler = async (event, context) => {
    return {"name": faker.name.findName()}
}

module.exports = {lambda_handler}