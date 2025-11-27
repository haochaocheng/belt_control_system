/***********************************************************************************
**    Qt6 Compatibility Header
**
**    This file declares opaque pointers for Risip types used in Q_PROPERTY
**    to resolve Qt6 metatype system requirements.
**
**    Each pointer type should only be declared once across the entire project.
************************************************************************************/
#ifndef RISIPMODELS_QT6_COMPAT_H
#define RISIPMODELS_QT6_COMPAT_H

#include <QtCore/qglobal.h>
#include <QtCore/qmetatype.h>

namespace risip {
    class RisipAccount;
    class RisipBuddy;
    class RisipCall;
    class RisipPhoneContact;
    class RisipContactManager;
}

// Qt6 compatibility: Declare opaque pointers for all Risip types
// These declarations must only appear once in the entire project
Q_DECLARE_OPAQUE_POINTER(risip::RisipAccount*)
Q_DECLARE_OPAQUE_POINTER(risip::RisipBuddy*)
Q_DECLARE_OPAQUE_POINTER(risip::RisipCall*)
Q_DECLARE_OPAQUE_POINTER(risip::RisipPhoneContact*)
Q_DECLARE_OPAQUE_POINTER(risip::RisipContactManager*)

#endif // RISIPMODELS_QT6_COMPAT_H
