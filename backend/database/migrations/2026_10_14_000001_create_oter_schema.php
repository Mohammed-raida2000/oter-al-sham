<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

// Runs the PostgreSQL schema that was validated with 12 constraint tests (database/schema.sql).
return new class extends Migration {
    public function up(): void
    {
        DB::unprepared(file_get_contents(database_path('schema.sql')));
    }

    public function down(): void
    {
        DB::unprepared('DROP SCHEMA public CASCADE; CREATE SCHEMA public;');
    }
};
