select *
from {{ source('my_schema', 'my_table') }}

/*
i am hoping that the time tracker picks up that i edited my sql file in my training folder 
*/