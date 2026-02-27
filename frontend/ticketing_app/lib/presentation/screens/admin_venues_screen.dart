import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/venue_model.dart';
import '../../domain/state/admin_state.dart';

class AdminVenuesScreen extends StatefulWidget {
  const AdminVenuesScreen({super.key});

  @override
  State<AdminVenuesScreen> createState() => _AdminVenuesScreenState();
}

class _AdminVenuesScreenState extends State<AdminVenuesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminState>().loadVenues();
    });
  }

  void _showVenueSheet({VenueModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VenueFormSheet(existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminState>(
      builder: (context, admin, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: admin.isLoading && admin.venues.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : admin.venues.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () => admin.loadVenues(),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: admin.venues.length,
                        itemBuilder: (_, i) =>
                            _VenueTile(venue: admin.venues[i],
                                onEdit: () =>
                                    _showVenueSheet(existing: admin.venues[i])),
                      ),
                    ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Add Venue'),
            onPressed: () => _showVenueSheet(),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_city_outlined,
                color: AppColors.textTertiary, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('No venues yet', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text('Tap + to create your first venue',
              style: AppTextStyles.body2),
        ],
      ),
    );
  }
}

class _VenueTile extends StatelessWidget {
  final VenueModel venue;
  final VoidCallback onEdit;

  const _VenueTile({required this.venue, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.stadium_rounded,
              color: AppColors.primary, size: 22),
        ),
        title: Text(venue.name, style: AppTextStyles.h4),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(venue.location,
                      style: AppTextStyles.body2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _pill('${venue.totalRows} rows', AppColors.primary),
                const SizedBox(width: 6),
                _pill('${venue.seatsPerRow} / row', AppColors.primary),
                const SizedBox(width: 6),
                _pill('${venue.totalCapacity} seats', AppColors.success),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined,
              color: AppColors.textSecondary, size: 20),
          onPressed: onEdit,
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: AppTextStyles.caption.copyWith(color: color)),
    );
  }
}

// ── Venue Form Bottom Sheet ────────────────────────────────────────────────

class _VenueFormSheet extends StatefulWidget {
  final VenueModel? existing;

  const _VenueFormSheet({this.existing});

  @override
  State<_VenueFormSheet> createState() => _VenueFormSheetState();
}

class _VenueFormSheetState extends State<_VenueFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _rowsCtrl;
  late final TextEditingController _seatsCtrl;

  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final v = widget.existing;
    _nameCtrl = TextEditingController(text: v?.name ?? '');
    _locationCtrl = TextEditingController(text: v?.location ?? '');
    _rowsCtrl = TextEditingController(
        text: v != null ? v.totalRows.toString() : '');
    _seatsCtrl = TextEditingController(
        text: v != null ? v.seatsPerRow.toString() : '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _rowsCtrl.dispose();
    _seatsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final admin = context.read<AdminState>();
    final rows = int.parse(_rowsCtrl.text.trim());
    final seats = int.parse(_seatsCtrl.text.trim());
    bool ok;
    if (_isEdit) {
      ok = await admin.updateVenue(
        widget.existing!.id,
        name: _nameCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        totalRows: rows,
        seatsPerRow: seats,
      );
    } else {
      ok = await admin.createVenue(
        name: _nameCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        totalRows: rows,
        seatsPerRow: seats,
      );
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Venue updated!' : 'Venue created!'),
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
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
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
              Text(
                _isEdit ? 'Edit Venue' : 'Create Venue',
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: 20),
              _field(_nameCtrl, 'Venue Name', 'e.g. City Arena',
                  Icons.stadium_rounded),
              const SizedBox(height: 12),
              _field(_locationCtrl, 'Location', 'e.g. Chennai, Tamil Nadu',
                  Icons.location_on_outlined),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(_rowsCtrl, 'Total Rows', 'e.g. 10',
                        Icons.view_week_outlined,
                        isNumber: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(_seatsCtrl, 'Seats / Row', 'e.g. 20',
                        Icons.airline_seat_recline_normal_outlined,
                        isNumber: true),
                  ),
                ],
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
                          _isEdit ? 'Update Venue' : 'Create Venue',
                          style: AppTextStyles.h4
                              .copyWith(color: Colors.white),
                        ),
                ),
              ),
            ],
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
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters:
          isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: AppTextStyles.body1,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.body2,
        hintText: hint,
        hintStyle: AppTextStyles.body2.copyWith(color: AppColors.textTertiary),
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
        if (v == null || v.trim().isEmpty) return 'Required';
        if (isNumber && int.tryParse(v.trim()) == null) return 'Enter a number';
        if (isNumber && int.parse(v.trim()) <= 0) return 'Must be > 0';
        return null;
      },
    );
  }
}
