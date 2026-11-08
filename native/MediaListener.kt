package __PACKAGE__

import android.service.notification.NotificationListenerService

/**
 * Servicio vacío: Android solo deja leer la música que suena (Spotify, YT Music…)
 * a las apps con "acceso a notificaciones". Este servicio es el que recibe ese permiso.
 */
class MediaListener : NotificationListenerService()
