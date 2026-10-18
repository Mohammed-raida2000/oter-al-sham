<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\CampController;
use App\Http\Controllers\DistributionController;
use App\Http\Controllers\FamilyController;
use App\Http\Controllers\FamilyDetailController;
use App\Http\Controllers\ProjectController;
use App\Http\Controllers\ReportController;
use App\Http\Controllers\UserController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::post('auth/login', [AuthController::class, 'login'])->middleware('throttle:10,1');

    Route::middleware('auth:sanctum')->group(function () {
        Route::get('auth/me', [AuthController::class, 'me']);
        Route::post('auth/logout', [AuthController::class, 'logout']);
        Route::patch('auth/preferences', [AuthController::class, 'preferences']);
        Route::get('dashboard', [ReportController::class, 'dashboard']);

        // Users (admin only)
        Route::middleware('perm:user.manage')->group(function () {
            Route::get('users', [UserController::class, 'index']);
            Route::post('users', [UserController::class, 'store']);
            Route::patch('users/{user}/active', [UserController::class, 'setActive']);
            Route::post('users/{user}/password', [UserController::class, 'resetPassword']);
            Route::get('roles', [UserController::class, 'roles']);
        });

        // Camps
        Route::middleware('perm:camp.view')->group(function () {
            Route::get('camps', [CampController::class, 'index']);
            Route::get('camps/{id}', [CampController::class, 'show']);
        });
        Route::middleware('perm:camp.manage')->group(function () {
            Route::post('camps', [CampController::class, 'store']);
            Route::patch('camps/{id}', [CampController::class, 'update']);
        });

        // Families
        Route::middleware('perm:family.view')->group(function () {
            Route::get('families', [FamilyController::class, 'index']);
            Route::get('families/{id}', [FamilyController::class, 'show'])->whereNumber('id');
            Route::get('need-types', [FamilyDetailController::class, 'needTypes']);
        });
        Route::middleware('perm:family.create')->group(function () {
            Route::get('families/check', [FamilyController::class, 'check']);
            Route::post('families', [FamilyController::class, 'store']);
        });
        Route::middleware('perm:family.update')->group(function () {
            Route::patch('families/{id}', [FamilyController::class, 'update']);
            Route::post('families/{id}/submit', [FamilyController::class, 'submit']);
            Route::post('families/{family}/members', [FamilyDetailController::class, 'addMember']);
            Route::patch('families/{family}/members/{member}', [FamilyDetailController::class, 'updateMember']);
            Route::delete('families/{family}/members/{member}', [FamilyDetailController::class, 'deleteMember']);
            Route::post('families/{family}/needs', [FamilyDetailController::class, 'addNeed']);
            Route::patch('families/{family}/needs/{need}', [FamilyDetailController::class, 'updateNeed']);
        });
        Route::middleware('perm:family.review')->group(function () {
            Route::get('reviews/pending', [FamilyController::class, 'pending']);
            Route::post('families/{id}/review', [FamilyController::class, 'review']);
        });
        Route::post('families/{id}/archive', [FamilyController::class, 'archive'])->middleware('perm:user.manage');

        // Projects
        Route::middleware('perm:project.view')->group(function () {
            Route::get('projects', [ProjectController::class, 'index']);
            Route::get('projects/{id}', [ProjectController::class, 'show']);
        });
        Route::middleware('perm:project.manage')->group(function () {
            Route::post('projects', [ProjectController::class, 'store']);
            Route::patch('projects/{id}', [ProjectController::class, 'update']);
        });

        // Distributions
        Route::middleware('perm:distribution.view')->group(function () {
            Route::get('distributions', [DistributionController::class, 'index']);
            Route::get('distributions/{id}', [DistributionController::class, 'show']);
            Route::get('assistance-types', [DistributionController::class, 'assistanceTypes']);
        });
        Route::middleware('perm:distribution.manage')->group(function () {
            Route::post('distributions', [DistributionController::class, 'store']);
            Route::patch('distributions/{id}/status', [DistributionController::class, 'setStatus']);
            Route::post('distributions/{id}/beneficiaries', [DistributionController::class, 'addBeneficiary']);
            Route::delete('distributions/{id}/beneficiaries/{family}', [DistributionController::class, 'removeBeneficiary']);
        });
        Route::post('distributions/{id}/beneficiaries/{family}/receive', [DistributionController::class, 'receive'])->middleware('perm:distribution.receive');

        // Reports
        Route::middleware('perm:report.view')->prefix('reports')->group(function () {
            Route::get('families-by-camp', [ReportController::class, 'familiesByCamp']);
            Route::get('families-by-status', [ReportController::class, 'byStatus']);
            Route::get('incomplete', [ReportController::class, 'incomplete']);
            Route::get('researchers', [ReportController::class, 'researcherActivity']);
            Route::get('projects', [ReportController::class, 'projectStats']);
        });
        Route::get('audit-logs', [ReportController::class, 'auditLog'])->middleware('perm:audit.view');
    });
});
