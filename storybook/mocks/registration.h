#pragma once

#include <QString>

class QQmlEngine;

// Registers the storybook-only QML types (module "StorybookMocks" 1.0). Global
// and idempotent.
void registerStorybookMockTypes();

// Types plus the image://walletmock provider, which is per-engine — PagesValidator
// builds a fresh QQmlEngine for every page, so this must run for each of them.
void registerStorybookMocks(QQmlEngine& engine);

// Instantiates every QML file under stubs/nim/sectionmocks and exposes it as the
// root context property named by its `contextPropertyName`. Shared by the
// storybook app, the pages validator and the qml tests so all three see the same
// backend surface.
void loadContextPropertiesMocks(QQmlEngine& engine, const QString& storybookRoot);
