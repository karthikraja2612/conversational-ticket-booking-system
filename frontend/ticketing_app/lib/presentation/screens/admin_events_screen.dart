import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/admin_event_model.dart';
import '../../domain/state/admin_state.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminState>().loadEvents();
    });
  }

  void _showEventSheet({AdminEventModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventFormSheet(existing: existing),
    );
  }

  void _showAnalytics(AdminEventModel event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AnalyticsSheet(event: event),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminState>(
      builder: (context, admin, _) {
        final events = admin.events;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: admin.isLoading && events.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : events.isEmpty
                  ? _buildEmpty(context)
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () => admin.loadEvents(),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: events.length,
                        itemBuilder: (_, i) => _EventTile(
                          event: events[i],
                          venueName: _venueName(admin, events[i].venueId),
                          onEdit: () => _showEventSheet(existing: events[i]),
                          onTogglePublish: () => admin.togglePublish(events[i]),
                          onAnalytics: () => _showAnalytics(events[i]),
                        ),
                      ),
                    ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('New Event'),
            onPressed: () => _showEventSheet(),
          ),
        );
      },
    );
  }

  String _venueName(AdminState admin, int venueId) {
    try {
      return admin.venues.firstWhere((v) => v.id == venueId).name;
    } catch (_) {
      return 'Venue #$venueId';
    }
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_outlined,
                color: AppColors.textTertiary, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('No events yet', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text('Tap + to create your first event', style: AppTextStyles.body2),
        ],
      ),
    );
  }
}

// ── Event Tile ────────────────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  final AdminEventModel event;
  final String venueName;
  final VoidCallback onEdit;
  final VoidCallback onTogglePublish;
  final VoidCallback onAnalytics;

  const _EventTile({
    required this.event,
    required this.venueName,
    required this.onEdit,
    required this.onTogglePublish,
    required this.onAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    final isPublished = event.isPublished;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPublished
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.confirmation_number_rounded,
                  color: AppColors.primary, size: 22),
            ),
            title: Row(
              children: [
                Expanded(
                    child: Text(event.name,
                        style: AppTextStyles.h4,
                        overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                _statusBadge(isPublished),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.stadium_rounded,
                        size: 13, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(venueName,
                          style: AppTextStyles.body2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 13, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(event.formattedDate, style: AppTextStyles.body2),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.currency_rupee_rounded,
                        size: 13, color: AppColors.textTertiary),
                    Text(
                        event.basePrice.toStringAsFixed(0),
                        style: AppTextStyles.body2),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _actionBtn(Icons.edit_outlined, 'Edit', onEdit,
                    AppColors.primary),
                _actionBtn(
                  isPublished
                      ? Icons.unpublished_outlined
                      : Icons.publish_rounded,
                  isPublished ? 'Unpublish' : 'Publish',
                  onTogglePublish,
                  isPublished ? AppColors.warning : AppColors.success,
                ),
                _actionBtn(Icons.bar_chart_rounded, 'Analytics', onAnalytics,
                    AppColors.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(bool published) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: published
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.textTertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        published ? 'LIVE' : 'DRAFT',
        style: AppTextStyles.label.copyWith(
          color: published ? AppColors.success : AppColors.textTertiary,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _actionBtn(
      IconData icon, String label, VoidCallback onPressed, Color color) {
    return Expanded(
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label, style: AppTextStyles.caption.copyWith(color: color)),
        style: TextButton.styleFrom(padding: const EdgeInsets.all(8)),
      ),
    );
  }
}

// ── Event Form Sheet ──────────────────────────────────────────────────────

class _EventFormSheet extends StatefulWidget {
  final AdminEventModel? existing;

  const _EventFormSheet({this.existing});

  @override
  State<_EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<_EventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _imageCtrl;
  DateTime? _selectedDate;
  int? _selectedVenueId;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _priceCtrl =
        TextEditingController(text: e != null ? e.basePrice.toString() : '');
    _imageCtrl = TextEditingController(text: e?.imageUrl ?? '');
    _selectedDate = e?.eventDate;
    _selectedVenueId = e?.venueId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _imageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime:
          _selectedDate != null ? TimeOfDay.fromDateTime(_selectedDate!) : TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return;

    setState(() {
      _selectedDate = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select event date & time'),
          backgroundColor: AppColors.error));
      return;
    }
    if (_selectedVenueId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a venue'),
          backgroundColor: AppColors.error));
      return;
    }

    setState(() => _submitting = true);
    final admin = context.read<AdminState>();
    final price = double.parse(_priceCtrl.text.trim());
    final imgUrl =
        _imageCtrl.text.trim().isNotEmpty ? _imageCtrl.text.trim() : null;

    bool ok;
    if (_isEdit) {
      ok = await admin.updateEvent(
        widget.existing!.id,
        name: _nameCtrl.text.trim(),
        eventDate: _selectedDate,
        basePrice: price,
        imageUrl: imgUrl,
      );
    } else {
      ok = await admin.createEvent(
        name: _nameCtrl.text.trim(),
        venueId: _selectedVenueId!,
        eventDate: _selectedDate!,
        basePrice: price,
        imageUrl: imgUrl,
      );
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Event updated!' : 'Event created! (Draft)'),
        backgroundColor: AppColors.success,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(admin.error ?? 'An error occurred'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    final venues = admin.venues;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderMedium,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(_isEdit ? 'Edit Event' : 'Create Event',
                    style: AppTextStyles.h3),
                const SizedBox(height: 20),
                // Name
                _field(_nameCtrl, 'Event Name', 'e.g. Music Night',
                    Icons.event_rounded),
                const SizedBox(height: 12),
                // Price
                _field(_priceCtrl, 'Base Price (₹)', 'e.g. 500',
                    Icons.currency_rupee_rounded,
                    isDecimal: true),
                const SizedBox(height: 12),
                // Image URL
                _field(_imageCtrl, 'Image URL (optional)',
                    'https://...', Icons.image_outlined,
                    required: false),
                const SizedBox(height: 12),
                // Venue Dropdown (only for create)
                if (!_isEdit) ...[
                  DropdownButtonFormField<int>(
                    value: _selectedVenueId,  // current selection binding
                    decoration: InputDecoration(
                      labelText: 'Venue',
                      labelStyle: AppTextStyles.body2,
                      prefixIcon: const Icon(Icons.stadium_rounded,
                          color: AppColors.textTertiary, size: 18),
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.borderSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                    ),
                    dropdownColor: AppColors.surfaceLight,
                    style: AppTextStyles.body1,
                    hint: Text('Select venue',
                        style: AppTextStyles.body2
                            .copyWith(color: AppColors.textTertiary)),
                    items: venues
                        .map((v) => DropdownMenuItem(
                              value: v.id,
                              child: Text('${v.name} (${v.location})'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedVenueId = v),
                    validator: (v) =>
                        v == null ? 'Please select a venue' : null,
                  ),
                  const SizedBox(height: 12),
                ],
                // Date picker
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined,
                            color: AppColors.textTertiary, size: 18),
                        const SizedBox(width: 12),
                        Text(
                          _selectedDate == null
                              ? 'Select date & time'
                              : '${_selectedDate!.day.toString().padLeft(2, '0')}/'
                                  '${_selectedDate!.month.toString().padLeft(2, '0')}/'
                                  '${_selectedDate!.year}  '
                                  '${_selectedDate!.hour.toString().padLeft(2, '0')}:'
                                  '${_selectedDate!.minute.toString().padLeft(2, '0')}',
                          style: _selectedDate == null
                              ? AppTextStyles.body2
                                  .copyWith(color: AppColors.textTertiary)
                              : AppTextStyles.body1,
                        ),
                        const Spacer(),
                        const Icon(Icons.edit_calendar_outlined,
                            color: AppColors.primary, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            _isEdit ? 'Update Event' : 'Create Event',
                            style: AppTextStyles.h4
                                .copyWith(color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon, {
    bool isDecimal = false,
    bool required = true,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isDecimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: AppTextStyles.body1,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.body2,
        hintText: hint,
        hintStyle:
            AppTextStyles.body2.copyWith(color: AppColors.textTertiary),
        prefixIcon: Icon(icon, color: AppColors.textTertiary, size: 18),
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: (v) {
        if (!required && (v == null || v.trim().isEmpty)) return null;
        if (v == null || v.trim().isEmpty) return 'Required';
        if (isDecimal && double.tryParse(v.trim()) == null) {
          return 'Enter a valid number';
        }
        if (isDecimal && double.parse(v.trim()) <= 0) return 'Must be > 0';
        return null;
      },
    );
  }
}

// ── Analytics Sheet ───────────────────────────────────────────────────────

class _AnalyticsSheet extends StatefulWidget {
  final AdminEventModel event;

  const _AnalyticsSheet({required this.event});

  @override
  State<_AnalyticsSheet> createState() => _AnalyticsSheetState();
}

class _AnalyticsSheetState extends State<_AnalyticsSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminState>().getAnalytics(widget.event.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Consumer<AdminState>(
        builder: (_, admin, __) {
          final data = admin.getCachedAnalytics(widget.event.id);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderMedium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.bar_chart_rounded,
                      color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.event.name,
                      style: AppTextStyles.h3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Analytics Overview', style: AppTextStyles.body2),
              const SizedBox(height: 24),
              if (data == null && admin.isLoading)
                const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
              else if (data == null)
                Center(
                  child: Text('No analytics data available.',
                      style: AppTextStyles.body2),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _statCard('Tickets Sold',
                        '${data['tickets_sold'] ?? 0}',
                        Icons.confirmation_number_outlined,
                        AppColors.success),
                    _statCard('Revenue',
                        '₹${(data['revenue'] as num?)?.toStringAsFixed(0) ?? '0'}',
                        Icons.currency_rupee_rounded,
                        AppColors.primary),
                    _statCard('Conversion',
                        '${((data['conversion_rate'] as num? ?? 0) * 100).toStringAsFixed(0)}%',
                        Icons.trending_up_rounded,
                        AppColors.warning),
                    _statCard('Abandoned',
                        '${data['abandoned_bookings'] ?? 0}',
                        Icons.shopping_cart_outlined,
                        AppColors.error),
                  ],
                ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: (MediaQuery.of(context).size.width - 60) / 2,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value,
              style: AppTextStyles.h2.copyWith(color: color, fontSize: 22)),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
