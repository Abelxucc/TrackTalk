import re

from django.db import IntegrityError
from django.views.decorators.cache import never_cache
from rest_framework import serializers, status
from rest_framework.authentication import TokenAuthentication
from rest_framework.decorators import (
    api_view, authentication_classes, parser_classes, permission_classes,
)
from rest_framework.parsers import JSONParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import AccountProfile


class ProfileFieldsSerializer(serializers.Serializer):
    phone_number = serializers.CharField(max_length=40, allow_blank=True, default="")
    gender = serializers.ChoiceField(choices=AccountProfile.Gender.choices, required=False)
    height_cm = serializers.DecimalField(
        max_digits=5, decimal_places=2, coerce_to_string=True,
        min_value=30, max_value=300, required=False,
    )
    weight_kg = serializers.DecimalField(
        max_digits=5, decimal_places=2, coerce_to_string=True,
        min_value=1, max_value=500, required=False,
    )
    age = serializers.IntegerField(min_value=1, max_value=120, required=False)

    def validate_phone_number(self, value):
        if not value:
            return ""
        # Accept readable formatting, but store only a leading + and digits.
        if not re.fullmatch(r"[+0-9 ()\-.]+", value):
            raise serializers.ValidationError("Enter a valid phone number.")
        normalized = re.sub(r"[ ()\-.]", "", value)
        if not re.fullmatch(r"\+?[0-9]{7,15}", normalized):
            raise serializers.ValidationError("Use 7 to 15 digits, with an optional country code.")
        return normalized


@never_cache
@api_view(["GET", "PATCH"])
@authentication_classes([TokenAuthentication])
@permission_classes([IsAuthenticated])
@parser_classes([JSONParser])
def account_profile(request):
    profile = AccountProfile.objects.filter(user=request.user).first()
    if request.method == "GET":
        return Response(ProfileFieldsSerializer(profile or AccountProfile()).data)

    serializer = ProfileFieldsSerializer(data=request.data, partial=True)
    serializer.is_valid(raise_exception=True)
    unknown_fields = request.data.keys() - serializer.fields.keys()
    if unknown_fields:
        raise serializers.ValidationError({
            field: ["This field cannot be updated."] for field in sorted(unknown_fields)
        })
    updates = serializer.validated_data
    if not updates:
        return Response(ProfileFieldsSerializer(profile or AccountProfile()).data)

    if profile is None:
        email = request.user.email.strip().lower()
        if not email:
            return Response(
                {"detail": "A sign-in email is required to save your profile."},
                status=status.HTTP_409_CONFLICT,
            )
        try:
            profile, created = AccountProfile.objects.get_or_create(
                user=request.user, defaults={"email": email, **updates},
            )
        except IntegrityError:
            return Response(
                {"detail": "Could not create a profile for this account."},
                status=status.HTTP_409_CONFLICT,
            )
        if created:
            return Response(ProfileFieldsSerializer(profile).data)

    # Update only supplied fields, so concurrent edits to other fields survive.
    for field, value in updates.items():
        setattr(profile, field, value)
    profile.save(update_fields=updates)
    profile.refresh_from_db(fields=serializer.fields)
    return Response(ProfileFieldsSerializer(profile).data)
