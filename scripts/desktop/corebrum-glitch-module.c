/* gtklock module. Adds the glitch class at each local minute.
   The CSS burst is one shot. The next wait is read from the system clock, so
   the picture stays with NTP instead of a free-running animation.
   gtklock 4.0.0 lays out struct Window with GdkMonitor * then GtkWidget *window.
   Keep the four timing numbers aligned with corebrum-login.py. */
#define _GNU_SOURCE

#include <time.h>
#include <gtk/gtk.h>

#define COREBRUM_GLITCH_PERIOD_MS 60000
#define COREBRUM_GLITCH_BURST_MS 1200
#define COREBRUM_GLITCH_GRACE_MS 200
#define COREBRUM_GLITCH_CLEAR_MS 1500

_Static_assert(COREBRUM_GLITCH_PERIOD_MS == 60000, "one-minute period");
_Static_assert(COREBRUM_GLITCH_CLEAR_MS > COREBRUM_GLITCH_BURST_MS + 140, "clear covers the 140ms bar stagger");

guint module_major_version = 4;
guint module_minor_version = 0;

struct CorebrumGtklockWindow {
	void *monitor;
	GtkWidget *window;
};

static const char *const source_key = "corebrum-glitch-source";

static gint64 into_period_ms(void) {
	struct timespec ts;
	struct tm local;

	if (clock_gettime(CLOCK_REALTIME, &ts) != 0)
		return 0;
	if (localtime_r(&ts.tv_sec, &local) == NULL)
		return (ts.tv_sec % 60) * 1000 + ts.tv_nsec / 1000000;
	return (local.tm_sec % 60) * 1000L + ts.tv_nsec / 1000000L;
}

static guint wait_ms(void) {
	gint64 into = into_period_ms();

	if (into <= COREBRUM_GLITCH_GRACE_MS)
		return 0;
	return (guint)(COREBRUM_GLITCH_PERIOD_MS - into);
}

static void arm(GtkWidget *window, guint delay_ms, GSourceFunc func) {
	guint id = g_timeout_add(delay_ms, func, window);
	g_object_set_data(G_OBJECT(window), source_key, GUINT_TO_POINTER(id));
}

static gboolean clear_glitch(gpointer data);
static gboolean start_glitch(gpointer data);

static gboolean clear_glitch(gpointer data) {
	GtkWidget *window = data;

	g_object_set_data(G_OBJECT(window), source_key, NULL);
	gtk_style_context_remove_class(gtk_widget_get_style_context(window), "glitch");
	arm(window, wait_ms(), start_glitch);
	return G_SOURCE_REMOVE;
}

static gboolean start_glitch(gpointer data) {
	GtkWidget *window = data;

	g_object_set_data(G_OBJECT(window), source_key, NULL);
	gtk_style_context_add_class(gtk_widget_get_style_context(window), "glitch");
	arm(window, COREBRUM_GLITCH_CLEAR_MS, clear_glitch);
	return G_SOURCE_REMOVE;
}

static void on_destroy(GtkWidget *window, gpointer data) {
	guint id = GPOINTER_TO_UINT(g_object_get_data(G_OBJECT(window), source_key));

	(void)data;
	if (id != 0)
		g_source_remove(id);
}

void on_window_create(void *gtklock, struct CorebrumGtklockWindow *win) {
	(void)gtklock;
	if (win == NULL || win->window == NULL)
		return;
	g_signal_connect(win->window, "destroy", G_CALLBACK(on_destroy), NULL);
	arm(win->window, wait_ms(), start_glitch);
}
